package com.wakemission.wake_mission_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Keeps a ring alive while the ringing screen comes up.
 *
 * A BroadcastReceiver finishes in milliseconds and its process is fair game
 * again the moment it returns. On ColorOS the app was frozen three seconds
 * after the alarm fired and the screen did not reach the foreground for
 * another nineteen -- the alarm was on time, the phone was simply silent
 * through all of it. A foreground service cannot be frozen, and Android
 * explicitly permits one to be started from an exact alarm, so the noise
 * starts on time and keeps going however long the UI takes.
 *
 * It owns the sound because it is the only link in the chain guaranteed to
 * run. The Dart alarm callback rides a JobService, which the same freezer
 * defers, so its notification is deliberately silent -- see
 * alarmFireCallback. The ringing screen calls stopNativeRing once it is up
 * and takes the sound from there.
 *
 * It does not launch the screen: the alarm broadcast carries the
 * background-activity-start grant and a service started from it does not
 * inherit that, so RingAlarmReceiver does the launching where the grant
 * lives. The full-screen intent here is the fallback when that is refused.
 */
class RingForegroundService : Service() {

    companion object {
        private const val TAG = "WakeForceRing"
        private const val CHANNEL = "ring_service_channel"

        const val EXTRA_KIND = "kind"
        const val EXTRA_ID = "id"
        const val EXTRA_NOTIFICATION_ID = "notificationId"

        /** A ring nobody ever stops is capped, not left screaming all day. */
        private const val MAX_RING_MS = 10 * 60 * 1000L

        /**
         * Whether this service is currently playing. The ringing screen asks
         * before starting its own tone: exactly one of them makes noise for
         * the whole ring, so there is no handover to hear and no way for the
         * two to end up on different sounds.
         */
        @Volatile
        var isRinging: Boolean = false
            private set

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, RingForegroundService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "could not stop ring service", e)
            }
        }
    }

    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val capHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val kind = intent?.getStringExtra(EXTRA_KIND) ?: "alarm"
        val id = intent?.getStringExtra(EXTRA_ID) ?: ""
        val notificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, 1) ?: 1

        // First thing, before anything that can throw: an FGS that does not
        // call this within a few seconds is killed outright.
        goForeground(notificationId, kind, id)

        acquireWakeLock()
        AlarmVolume.boost(this)
        startRinging()
        isRinging = true

        capHandler.removeCallbacksAndMessages(null)
        capHandler.postDelayed({ stopSelf() }, MAX_RING_MS)
        Log.i(TAG, "ring service up for $kind $id")
        return START_NOT_STICKY
    }

    private fun goForeground(notificationId: Int, kind: String, id: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Alarm ringing",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Shown while an alarm or block is ringing"
                    // Silent: this service plays the tone itself. A channel
                    // that also sounded would ring over the top of it.
                    setSound(null, null)
                    enableVibration(false)
                }
            )
        }

        val full = PendingIntent.getActivity(
            this,
            notificationId,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(RingAlarmReceiver.EXTRA_KIND, kind)
                putExtra(RingAlarmReceiver.EXTRA_ID, id)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle(if (kind == "block") "Routine block" else "Wake up!")
            .setContentText("Tap to open your mission")
            .setSmallIcon(applicationInfo.icon)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(full)
            // The second route in, for when a background activity start is
            // refused outright.
            .setFullScreenIntent(full, true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(notificationId, notification)
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "WakeForce:ring",
            ).apply { acquire(MAX_RING_MS) }
        } catch (e: Exception) {
            Log.w(TAG, "could not hold wake lock", e)
        }
    }

    private fun startRinging() {
        try {
            // Built by hand rather than MediaPlayer.create(): create() prepares
            // the player itself, and setAudioAttributes is only honoured before
            // prepare. Set afterwards it is silently ignored and the tone comes
            // out of the media stream -- which is why the alarm was loud until
            // the ringing screen took over on the (quieter) alarm stream.
            //
            // res/raw/routine_chime is byte-identical to the Flutter asset that
            // screen plays, so on the same stream the handover is inaudible.
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(
                    this@RingForegroundService,
                    // By id, not by name: this is a real reference to the
                    // resource, which is what stops the release shrinker
                    // deleting it. See res/raw/keep.xml.
                    Uri.parse("android.resource://$packageName/${R.raw.routine_chime}"),
                )
                isLooping = true
                prepare()
                start()
            }
            Log.i(TAG, "alarm tone playing")
        } catch (e: Exception) {
            // Never fail quietly here. A swallowed exception on this path is an
            // alarm that shows a notification and makes no noise, which is the
            // one outcome the whole service exists to prevent.
            Log.w(TAG, "bundled tone failed; falling back to the system alarm", e)
            player = try {
                MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(
                        this@RingForegroundService,
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    )
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (e2: Exception) {
                Log.e(TAG, "no alarm tone could be played at all", e2)
                null
            }
        }

        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                    as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val pattern = longArrayOf(0, 800, 400, 800, 400, 800)
            vibrator.vibrate(
                VibrationEffect.createWaveform(pattern, 0),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build(),
            )
        } catch (e: Exception) {
            Log.w(TAG, "could not vibrate", e)
        }
    }

    override fun onDestroy() {
        isRinging = false
        capHandler.removeCallbacksAndMessages(null)
        AlarmVolume.restore(this)
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                    as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator.cancel()
        } catch (_: Exception) {
        }
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        Log.i(TAG, "ring service down")
        super.onDestroy()
    }
}
