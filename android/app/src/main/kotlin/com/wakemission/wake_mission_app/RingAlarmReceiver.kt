package com.wakemission.wake_mission_app

import android.app.ActivityOptions
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Calendar

/**
 * Brings the ringing screen to the front by itself, whatever app is open.
 *
 * Android 14+ downgrades a full-screen intent to a heads-up notification
 * unless the user has allowed full-screen notifications, which leaves the
 * alarm waiting to be tapped -- not an alarm at all. "Draw over other apps"
 * carries background-activity-start privileges, so when that is granted this
 * launches the activity directly instead of asking the notification to do it.
 *
 * A recurring ring re-arms itself here rather than in Dart: when this fires
 * the app is usually dead, and the isolate that wakes up has no method
 * channel to reach native code with. Without this the screen only ever came
 * up on the first day and every day after was a silent notification.
 *
 * The notification is still posted alongside, so the alarm survives even if
 * neither permission is available.
 */
class RingAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WakeForceRing"

        const val EXTRA_KIND = "kind"      // "alarm" or "block"
        const val EXTRA_ID = "id"
        private const val EXTRA_REQUEST_CODE = "requestCode"
        /** Weekdays this recurs on, 1 = Mon .. 7 = Sun. Absent = fires once. */
        private const val EXTRA_DAYS = "days"
        private const val EXTRA_TRIGGER_AT = "triggerAt"
        /** Whether this ring takes over the screen, or only chimes. */
        private const val EXTRA_SCREEN = "screen"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"

        /**
         * Must match the id and settings the Dart side uses for the same
         * channel: whichever process posts first creates it, and an Android
         * channel is immutable once created, so the two have to agree.
         */
        private const val ROUTINE_CHANNEL = "routine_channel_v3"

        /** Flutter's SharedPreferences plugin prefixes every key with this. */
        private const val FLUTTER_PREFIX = "flutter."
        private const val PREFS = "FlutterSharedPreferences"

        /**
         * Our own record of what is armed, keyed by request code. Android
         * drops every AlarmManager entry on reboot and on an app update, and
         * nothing else on the device remembers these -- the Dart alarms come
         * back through the plugin's own reboot receiver, but the native rings
         * that actually put the screen in front of you do not.
         */
        private const val STORE = "WakeForceNativeRings"

        private fun pendingIntentFor(
            context: Context,
            requestCode: Int,
            kind: String,
            id: String,
            days: IntArray?,
            triggerAtMillis: Long,
            screen: Boolean = true,
            title: String = "",
            body: String = "",
        ): PendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, RingAlarmReceiver::class.java).apply {
                putExtra(EXTRA_KIND, kind)
                putExtra(EXTRA_ID, id)
                putExtra(EXTRA_REQUEST_CODE, requestCode)
                putExtra(EXTRA_TRIGGER_AT, triggerAtMillis)
                putExtra(EXTRA_SCREEN, screen)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                if (days != null) putExtra(EXTRA_DAYS, days)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        fun schedule(
            context: Context,
            requestCode: Int,
            kind: String,
            id: String,
            triggerAtMillis: Long,
            days: IntArray? = null,
            screen: Boolean = true,
            title: String = "",
            body: String = "",
        ): Boolean {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = pendingIntentFor(
                context, requestCode, kind, id, days, triggerAtMillis, screen, title, body
            )
            return try {
                // setAlarmClock is the highest-priority class of alarm: it is
                // exempt from Doze batching, which a wake alarm has to be.
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pi), pi)
                record(context, requestCode, kind, id, triggerAtMillis, days, screen, title, body)
                true
            } catch (e: Exception) {
                Log.w(TAG, "could not schedule native ring", e)
                false
            }
        }

        fun cancel(context: Context, requestCode: Int, kind: String, id: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            try {
                // Extras play no part in PendingIntent matching, so the zeroes
                // here still resolve to whatever was scheduled.
                am.cancel(pendingIntentFor(context, requestCode, kind, id, null, 0L))
                forget(context, requestCode)
            } catch (e: Exception) {
                Log.w(TAG, "could not cancel native ring", e)
            }
        }

        private fun store(context: Context) =
            context.getSharedPreferences(STORE, Context.MODE_PRIVATE)

        // "kind|id|triggerAt|1,3,5|screen|title|body" -- ids are UUIDs and the
        // title/body are the last fields, so a pipe typed into a block title
        // cannot shift anything that is parsed by position.
        private fun record(
            context: Context,
            requestCode: Int,
            kind: String,
            id: String,
            triggerAtMillis: Long,
            days: IntArray?,
            screen: Boolean,
            title: String,
            body: String,
        ) {
            try {
                store(context).edit()
                    .putString(
                        requestCode.toString(),
                        "$kind|$id|$triggerAtMillis|" +
                            (days?.joinToString(",") ?: "") +
                            "|$screen|$title|$body",
                    )
                    .apply()
            } catch (e: Exception) {
                Log.w(TAG, "could not record native ring", e)
            }
        }

        private fun forget(context: Context, requestCode: Int) {
            try {
                store(context).edit().remove(requestCode.toString()).apply()
            } catch (e: Exception) {
                Log.w(TAG, "could not forget native ring", e)
            }
        }

        /**
         * Re-arms everything after a reboot or an app update, both of which
         * wipe AlarmManager. Called from [BootReceiver] so a phone that was
         * off overnight still rings in the morning without the student having
         * to open the app first.
         */
        fun restoreAll(context: Context) {
            val now = System.currentTimeMillis()
            val entries = try {
                store(context).all
            } catch (e: Exception) {
                Log.w(TAG, "could not read recorded native rings", e)
                return
            }

            for ((key, value) in entries) {
                val requestCode = key.toIntOrNull() ?: continue
                val parts = (value as? String)?.split("|") ?: continue
                if (parts.size < 4) continue
                val at = parts[2].toLongOrNull() ?: continue
                val days = parts[3]
                    .split(",")
                    .mapNotNull { it.toIntOrNull() }
                    .toIntArray()

                val next = when {
                    at > now -> at
                    days.isNotEmpty() -> nextOccurrence(at, days, now)
                    // A one-shot whose time passed while the phone was off:
                    // going off hours late is worse than not going off, so it
                    // is dropped rather than fired on boot.
                    else -> {
                        forget(context, requestCode)
                        continue
                    }
                }
                schedule(
                    context,
                    requestCode,
                    parts[0],
                    parts[1],
                    next,
                    days.takeIf { it.isNotEmpty() },
                    // Records written before these fields existed default to
                    // taking over the screen, which is what they used to do.
                    screen = parts.getOrNull(4)?.toBooleanStrictOrNull() ?: true,
                    title = parts.getOrNull(5) ?: "",
                    // Rejoined: a title containing a pipe would otherwise have
                    // truncated its own body.
                    body = parts.drop(6).joinToString("|"),
                )
            }
            Log.i(TAG, "restored ${entries.size} native ring(s)")
        }

        /**
         * Opens the ringing screen without the student touching anything.
         *
         * Sent as a PendingIntent that opts in to a background activity start,
         * not a plain startActivity. Android 14 refuses a direct start from the
         * background and says why in the denial: "autoOptInReason:
         * notPendingIntent" and "balRequireOptInByPendingIntentCreator: true"
         * -- it wants the sender to ask for this explicitly, which a direct
         * start has no way of doing.
         *
         * A vendor layer can still refuse: on ColorOS,
         * BackgroundActivityStartControllerExtImpl denies the start 8ms after
         * AOSP has allowed it for SYSTEM_ALERT_WINDOW, and no app-side call
         * gets past that -- it needs the phone's own "display pop-up windows
         * while running in the background" switch. The notification's
         * full-screen intent stays as the fallback, and is what carries the
         * locked-screen case regardless.
         */
        private fun launchRingingScreen(
            context: Context,
            requestCode: Int,
            kind: String,
            id: String,
        ) {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra(EXTRA_KIND, kind)
                putExtra(EXTRA_ID, id)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    // Both halves have to opt in. The denial names them
                    // separately: balRequireOptInByPendingIntentCreator is
                    // true, so opting in only on send left
                    // balAllowedByPiCreator at BSP.NONE and the start was
                    // still refused.
                    val creatorOptIn = ActivityOptions.makeBasic()
                        .setPendingIntentCreatorBackgroundActivityStartMode(
                            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                        )
                        .toBundle()
                    val senderOptIn = ActivityOptions.makeBasic()
                        .setPendingIntentBackgroundActivityStartMode(
                            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                        )
                        .toBundle()
                    PendingIntent.getActivity(
                        context,
                        requestCode,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                        creatorOptIn,
                    ).send(context, 0, null, null, null, null, senderOptIn)
                } else {
                    context.startActivity(intent)
                }
                Log.i(TAG, "launched ringing screen for $kind $id")
            } catch (e: Exception) {
                Log.w(TAG, "activity start refused; full-screen intent only", e)
            }
        }

        /**
         * The next instant at the same wall-clock time landing on one of
         * [days], after now. Stepping calendar days rather than adding 24h
         * keeps the alarm at the time the student set across a DST shift.
         */
        internal fun nextOccurrence(
            firedAtMillis: Long,
            days: IntArray,
            nowMillis: Long,
        ): Long {
            val cal = Calendar.getInstance().apply { timeInMillis = firedAtMillis }
            // Eight steps covers a full week from any starting day, plus the
            // one wasted step when the phone was off past the next occurrence.
            repeat(8) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
                if (cal.timeInMillis > nowMillis && days.contains(isoWeekday(cal))) {
                    return cal.timeInMillis
                }
            }
            return cal.timeInMillis
        }

        /** Calendar.SUNDAY is 1; the app counts 1 = Monday .. 7 = Sunday. */
        private fun isoWeekday(cal: Calendar): Int {
            val d = cal.get(Calendar.DAY_OF_WEEK)
            return if (d == Calendar.SUNDAY) 7 else d - 1
        }
    }

    /**
     * Posts a routine block's reminder from native code. Same notification id
     * as the Dart side uses, so if both manage to run only one lands.
     */
    private fun chime(context: Context, id: Int, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        ROUTINE_CHANNEL,
                        "Routine reminders",
                        NotificationManager.IMPORTANCE_HIGH,
                    ).apply {
                        description = "A short chime when a routine block starts"
                        // Alarm usage, not notification: a phone on vibrate
                        // silences the notification stream, and a block the
                        // student asked to be reminded about is not optional.
                        setSound(
                            Uri.parse(
                                // By id -- see RingForegroundService.
                                "android.resource://${context.packageName}/" +
                                    "${R.raw.routine_chime}"
                            ),
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(
                                    AudioAttributes.CONTENT_TYPE_SONIFICATION
                                )
                                .build(),
                        )
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800)
                    }
                )
            }
            val open = PendingIntent.getActivity(
                context,
                id,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            nm.notify(
                id,
                NotificationCompat.Builder(context, ROUTINE_CHANNEL)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(context.applicationInfo.icon)
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .setContentIntent(open)
                    .build(),
            )
            Log.i(TAG, "chimed routine reminder $id")
        } catch (e: Exception) {
            Log.w(TAG, "could not post routine reminder", e)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val kind = intent.getStringExtra(EXTRA_KIND) ?: return
        val id = intent.getStringExtra(EXTRA_ID) ?: return

        // Written where the Dart side already looks, so the existing
        // resume-handling opens the right screen with no new plumbing.
        val key = if (kind == "block") "pendingRingBlockId" else "pendingRingAlarmId"
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(FLUTTER_PREFIX + key, id)
                .commit()
        } catch (e: Exception) {
            Log.w(TAG, "could not persist pending ring", e)
        }

        // Before the activity start, not after: a blocked start throws, and
        // the next occurrence must be armed either way.
        val days = intent.getIntArrayExtra(EXTRA_DAYS)
        val firedAt = intent.getLongExtra(EXTRA_TRIGGER_AT, 0L)
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, 0)
        if (days != null && days.isNotEmpty() && firedAt > 0L) {
            val next = nextOccurrence(firedAt, days, System.currentTimeMillis())
            schedule(context, requestCode, kind, id, next, days)
            Log.i(TAG, "re-armed native ring for $kind $id at $next")
        } else {
            // Spent: leave nothing for the next reboot to restore.
            forget(context, requestCode)
        }

        // A plain reminder announces itself and stops there. It still comes
        // through this receiver rather than the Dart alarm alone, because a
        // manifest broadcast is delivered on a phone whose app process the OEM
        // has frozen -- the background isolate that would otherwise post this
        // is not.
        if (!intent.getBooleanExtra(EXTRA_SCREEN, true)) {
            chime(
                context,
                requestCode,
                intent.getStringExtra(EXTRA_TITLE) ?: "",
                intent.getStringExtra(EXTRA_BODY) ?: "",
            )
            return
        }

        // Hand straight to the foreground service rather than starting the
        // activity here. This receiver returns in milliseconds and its process
        // is freezable again immediately -- which is what left the phone silent
        // for 19 seconds after an alarm that had fired exactly on time. A
        // foreground service cannot be frozen, and starting one is allowed
        // from an exact alarm.
        try {
            val service = Intent(context, RingForegroundService::class.java).apply {
                putExtra(RingForegroundService.EXTRA_KIND, kind)
                putExtra(RingForegroundService.EXTRA_ID, id)
                putExtra(RingForegroundService.EXTRA_NOTIFICATION_ID, requestCode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
            Log.i(TAG, "handed $kind $id to the ring service")

            // Launched from here, not from the service: the alarm broadcast is
            // what carries the background-activity-start grant, and a service
            // started from it does not inherit that. Done after the service so
            // the sound is already going if this is refused.
            launchRingingScreen(context, requestCode, kind, id)
        } catch (e: Exception) {
            // Refused: make the noise from here instead, so the alarm is never
            // silent just because the service could not start.
            Log.w(TAG, "ring service refused; falling back to notification", e)
            chime(
                context,
                requestCode,
                intent.getStringExtra(EXTRA_TITLE) ?: "Wake up!",
                intent.getStringExtra(EXTRA_BODY) ?: "",
            )
        }
    }
}
