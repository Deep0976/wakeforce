package com.wakemission.wake_mission_app

import android.app.KeyguardManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val focusChannel = "wakeforce/focus"

    /// The ring that launched us, straight off the Intent.
    ///
    /// Not through SharedPreferences: the receiver writes the legacy XML store
    /// and Dart's SharedPreferencesAsync reads DataStore -- same name, two
    /// different files, so the value never arrived and the app opened on its
    /// normal screen. Tapping the notification worked only because that path
    /// carries the id in the payload instead.
    private var pendingRingKind: String? = null
    private var pendingRingId: String? = null

    private fun capturePendingRing(from: Intent?) {
        val kind = from?.getStringExtra(RingAlarmReceiver.EXTRA_KIND) ?: return
        val id = from.getStringExtra(RingAlarmReceiver.EXTRA_ID) ?: return
        if (id.isEmpty()) return
        pendingRingKind = kind
        pendingRingId = id
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A ring arriving while the app is already open comes through here
        // rather than onCreate, which is the usual case: the student had the
        // app in the background.
        setIntent(intent)
        capturePendingRing(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        capturePendingRing(intent)

        // Required so the alarm's full-screen notification intent can pop this
        // activity directly over the lock screen and wake the display, instead
        // of silently queuing as a normal notification the user has to find
        // and tap. Without this, the alarm never actually "rings" while the
        // phone is locked -- exactly the scenario an alarm app has to cover.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val keyguardManager = getSystemService(KeyguardManager::class.java)
        keyguardManager?.requestDismissKeyguard(this, null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Do Not Disturb can only be changed from native code: there is no
        // Flutter plugin for setInterruptionFilter, so a Focus session that
        // claims to silence the phone has to reach through this channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, focusChannel)
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager

                when (call.method) {
                    "isDndGranted" -> result.success(
                        nm.isNotificationPolicyAccessGranted
                    )

                    "setDnd" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (!nm.isNotificationPolicyAccessGranted) {
                            // Never throw here: losing DND must not take the
                            // focus session down with it.
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            if (on) {
                                // Repeat callers get through: a second call
                                // from the same number inside 15 minutes is
                                // how a real emergency reaches a student
                                // whose phone is otherwise silent.
                                nm.notificationPolicy = NotificationManager.Policy(
                                    NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS,
                                    0,
                                    0
                                )
                                nm.setInterruptionFilter(
                                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                                )
                            } else {
                                nm.setInterruptionFilter(
                                    NotificationManager.INTERRUPTION_FILTER_ALL
                                )
                            }
                            result.success(true)
                        } catch (e: SecurityException) {
                            result.success(false)
                        }
                    }

                    // Routed natively rather than through permission_handler:
                    // this is the screen ColorOS actually resolves, and the
                    // plugin's own request was not reliably landing on it.
                    "requestDnd" -> {
                        openSettings(
                            Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS
                        )
                        result.success(null)
                    }

                    "isAirplaneOn" -> result.success(
                        Settings.Global.getInt(
                            contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0
                        ) == 1
                    )

                    // No API can toggle airplane mode on modern Android, so
                    // the app opens the screen and reports back what the
                    // student actually did rather than claiming to set it.
                    "openAirplaneSettings" -> {
                        openSettings(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
                        result.success(null)
                    }

                    "scheduleNativeRing" -> {
                        val id = call.argument<String>("id") ?: ""
                        val kind = call.argument<String>("kind") ?: "alarm"
                        val code = call.argument<Int>("requestCode") ?: 0
                        val at = call.argument<Long>("triggerAtMillis") ?: 0L
                        // Absent means "fires once"; a list means re-arm
                        // natively on those weekdays (1 = Mon .. 7 = Sun).
                        val days = call.argument<List<Int>>("repeatDays")
                            ?.toIntArray()
                        result.success(
                            if (id.isEmpty() || at <= 0) false
                            else RingAlarmReceiver.schedule(
                                this, code, kind, id, at, days,
                                screen = call.argument<Boolean>("screen") ?: true,
                                title = call.argument<String>("title") ?: "",
                                body = call.argument<String>("body") ?: "",
                            )
                        )
                    }

                    // The ringing screen asks this before starting its own
                    // tone. If the service is already playing it keeps
                    // playing: one sound source for the whole ring, so there
                    // is no seam and no chance of the two being on different
                    // tones (the service falls back to the system alarm when
                    // the bundled one will not open).
                    // Peek, not consume: Dart may ask before its providers
                    // have loaded and cannot act yet. It clears this itself
                    // once it has actually opened the screen.
                    "peekPendingRing" -> result.success(
                        pendingRingId?.let {
                            mapOf("kind" to pendingRingKind, "id" to it)
                        }
                    )

                    "clearPendingRing" -> {
                        pendingRingKind = null
                        pendingRingId = null
                        result.success(null)
                    }

                    "isNativeRinging" -> result.success(
                        RingForegroundService.isRinging
                    )

                    // The alarm is actually over now, so the service that
                    // carried it here can stand down.
                    "stopNativeRing" -> {
                        RingForegroundService.stop(this)
                        result.success(null)
                    }

                    "boostAlarmVolume" -> {
                        AlarmVolume.boost(this)
                        result.success(null)
                    }

                    "restoreAlarmVolume" -> {
                        AlarmVolume.restore(this)
                        result.success(null)
                    }

                    "cancelNativeRing" -> {
                        val id = call.argument<String>("id") ?: ""
                        val kind = call.argument<String>("kind") ?: "alarm"
                        val code = call.argument<Int>("requestCode") ?: 0
                        if (id.isNotEmpty()) {
                            RingAlarmReceiver.cancel(this, code, kind, id)
                        }
                        result.success(null)
                    }

                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "requestUsageAccess" -> {
                        openSettings(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        result.success(null)
                    }

                    "hasOverlay" -> result.success(Settings.canDrawOverlays(this))
                    "requestOverlay" -> {
                        openSettings(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        result.success(null)
                    }

                    "installedApps" -> result.success(installedApps())

                    "startGuard" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        val block = call.argument<Boolean>("block") ?: true
                        FocusGuardService.resetCounts()
                        val i = Intent(this, FocusGuardService::class.java).apply {
                            action = FocusGuardService.ACTION_START
                            putStringArrayListExtra(
                                FocusGuardService.EXTRA_PACKAGES, ArrayList(packages)
                            )
                            putExtra(FocusGuardService.EXTRA_BLOCK, block)
                        }
                        try {
                            startForegroundService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "stopGuard" -> {
                        // Read the tallies out before the service tears down.
                        val counts = HashMap(FocusGuardService.counts)
                        try {
                            startService(
                                Intent(this, FocusGuardService::class.java).apply {
                                    action = FocusGuardService.ACTION_STOP
                                }
                            )
                        } catch (_: Exception) {
                        }
                        result.success(counts.mapKeys { labelFor(it.key) })
                    }

                    "canFullScreen" -> result.success(
                        if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent()
                        else true
                    )
                    "requestFullScreen" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            openSettings(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                Uri.parse("package:$packageName")
                            )
                        }
                        result.success(null)
                    }


                    else -> result.notImplemented()
                }
            }
    }

    private fun openSettings(action: String, data: Uri? = null) {
        try {
            startActivity(Intent(action).apply {
                if (data != null) this.data = data
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        } catch (e: Exception) {
            // Some OEM builds hide these screens; the caller re-checks the
            // permission on resume either way.
        }
    }

    private fun hasUsageAccess(): Boolean = try {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        ops.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        ) == AppOpsManager.MODE_ALLOWED
    } catch (e: Exception) {
        false
    }

    private fun labelFor(pkg: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(pkg, 0)
        ).toString()
    } catch (e: Exception) {
        pkg
    }

    /** Launchable, non-system apps -- the only ones worth offering to shield. */
    private fun installedApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .mapNotNull { ri ->
                val pkg = ri.activityInfo.packageName
                if (pkg == packageName) return@mapNotNull null
                mapOf("package" to pkg, "label" to ri.loadLabel(pm).toString())
            }
            .distinctBy { it["package"] }
            .sortedBy { it["label"]?.lowercase() }
    }
}
