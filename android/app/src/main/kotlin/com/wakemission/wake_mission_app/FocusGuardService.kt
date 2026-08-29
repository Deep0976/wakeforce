package com.wakemission.wake_mission_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Keeps a focus session honest: while it runs, this service watches which app
 * is in the foreground and covers the blocked ones with a full-screen panel.
 *
 * Deliberately a poll rather than an accessibility service. Usage access is
 * the permission students already understand, and an accessibility service
 * reads screen content -- far more power than blocking needs, and a much
 * harder review conversation on Play.
 */
class FocusGuardService : Service() {

    companion object {
        const val ACTION_START = "wakeforce.guard.START"
        const val ACTION_STOP = "wakeforce.guard.STOP"
        const val EXTRA_PACKAGES = "packages"
        const val EXTRA_BLOCK = "block"

        private const val CHANNEL_ID = "focus_guard_channel"
        private const val NOTIFICATION_ID = 90210

        /** Interruption tallies, read back by Dart when the session ends. */
        @Volatile
        var counts: MutableMap<String, Int> = mutableMapOf()
            private set

        @Volatile
        var running = false
            private set

        fun resetCounts() {
            counts = mutableMapOf()
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var blocked: Set<String> = emptySet()
    private var blockEnabled = true
    private var overlay: View? = null
    private var overlayFor: String? = null

    /**
     * Only counts a fresh switch into an app, not every poll tick -- otherwise
     * one visit to Instagram would register as dozens of interruptions.
     */
    private var lastForeground: String? = null

    private val poll = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (_: Exception) {
                // A guard that crashes must not take the focus session with it.
            }
            handler.postDelayed(this, 900)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A null intent means the system restarted us after the process died.
        // There is no session state left to guard, and returning without
        // calling startForeground would crash the app, so shut down cleanly.
        if (intent == null) {
            stop()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_STOP -> {
                stop()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                blocked = intent.getStringArrayListExtra(EXTRA_PACKAGES)?.toSet() ?: emptySet()
                blockEnabled = intent.getBooleanExtra(EXTRA_BLOCK, true)
                startForeground(NOTIFICATION_ID, buildNotification())
                running = true
                lastForeground = null
                handler.removeCallbacks(poll)
                handler.post(poll)
            }
        }
        // Not sticky: a focus session belongs to a screen the student is
        // looking at. Restarting the guard on its own after a process death
        // would leave apps shielded with no way to end the session.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }

    private fun stop() {
        running = false
        handler.removeCallbacks(poll)
        removeOverlay()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): android.app.Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Focus session",
                    // Low: this notification is a legal requirement for a
                    // foreground service, not something to interrupt with.
                    NotificationManager.IMPORTANCE_LOW
                ).apply { setShowBadge(false) }
            )
        }
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return androidx.core.app.NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus session running")
            .setContentText("Distracting apps are shielded until you finish.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }

    private fun currentForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        // A 10s window: long enough to always contain the last switch, short
        // enough that we don't walk a big list every second.
        val events = usm.queryEvents(now - 10_000, now)
        var pkg: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                pkg = event.packageName
            }
        }
        return pkg
    }

    private fun check() {
        val pkg = currentForegroundPackage() ?: return
        if (pkg == packageName) {
            removeOverlay()
            lastForeground = pkg
            return
        }

        if (!blocked.contains(pkg)) {
            removeOverlay()
            lastForeground = pkg
            return
        }

        // Count once per entry into the app.
        if (lastForeground != pkg) {
            counts[pkg] = (counts[pkg] ?: 0) + 1
        }
        lastForeground = pkg

        if (blockEnabled) showOverlay(pkg) else removeOverlay()
    }

    private fun showOverlay(pkg: String) {
        if (overlay != null && overlayFor == pkg) return
        removeOverlay()
        if (!canOverlay()) return

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val label = appLabel(pkg)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2100C08"))
            setPadding(70, 0, 70, 0)
        }
        root.addView(TextView(this).apply {
            text = "You're in focus"
            setTextColor(Color.parseColor("#F4F6F8"))
            textSize = 27f
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = "$label is shielded until your block ends."
            setTextColor(Color.parseColor("#C3CAD3"))
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(0, 26, 0, 40)
        })
        root.addView(Button(this).apply {
            text = "Back to study"
            setOnClickListener {
                removeOverlay()
                startActivity(
                    Intent(this@FocusGuardService, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        })

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )

        try {
            wm.addView(root, params)
            overlay = root
            overlayFor = pkg
        } catch (_: Exception) {
            overlay = null
            overlayFor = null
        }
    }

    private fun removeOverlay() {
        val v = overlay ?: return
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Exception) {
            // Already gone.
        }
        overlay = null
        overlayFor = null
    }

    private fun canOverlay(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            android.provider.Settings.canDrawOverlays(this)

    private fun appLabel(pkg: String): String = try {
        val pm = packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) {
        pkg
    }
}
