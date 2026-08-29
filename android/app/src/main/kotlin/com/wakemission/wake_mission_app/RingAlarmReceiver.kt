package com.wakemission.wake_mission_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Brings the ringing screen to the front by itself, whatever app is open.
 *
 * Android 14+ downgrades a full-screen intent to a heads-up notification
 * unless the user has allowed full-screen notifications, which leaves the
 * alarm waiting to be tapped -- not an alarm at all. "Draw over other apps"
 * carries background-activity-start privileges, so when that is granted this
 * launches the activity directly instead of asking the notification to do it.
 *
 * The notification is still posted alongside, so the alarm survives even if
 * neither permission is available.
 */
class RingAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WakeForceRing"

        const val EXTRA_KIND = "kind"      // "alarm" or "block"
        const val EXTRA_ID = "id"

        /** Flutter's SharedPreferences plugin prefixes every key with this. */
        private const val FLUTTER_PREFIX = "flutter."
        private const val PREFS = "FlutterSharedPreferences"

        private fun pendingIntentFor(
            context: Context,
            requestCode: Int,
            kind: String,
            id: String,
        ): PendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, RingAlarmReceiver::class.java).apply {
                putExtra(EXTRA_KIND, kind)
                putExtra(EXTRA_ID, id)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        fun schedule(
            context: Context,
            requestCode: Int,
            kind: String,
            id: String,
            triggerAtMillis: Long,
        ): Boolean {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = pendingIntentFor(context, requestCode, kind, id)
            return try {
                // setAlarmClock is the highest-priority class of alarm: it is
                // exempt from Doze batching, which a wake alarm has to be.
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pi), pi)
                true
            } catch (e: Exception) {
                Log.w(TAG, "could not schedule native ring", e)
                false
            }
        }

        fun cancel(context: Context, requestCode: Int, kind: String, id: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            try {
                am.cancel(pendingIntentFor(context, requestCode, kind, id))
            } catch (e: Exception) {
                Log.w(TAG, "could not cancel native ring", e)
            }
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

        try {
            context.startActivity(
                Intent(context, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    )
                    putExtra(EXTRA_KIND, kind)
                    putExtra(EXTRA_ID, id)
                }
            )
            Log.i(TAG, "launched ringing screen for $kind $id")
        } catch (e: Exception) {
            // Without the overlay permission Android blocks a background
            // activity start. The notification is still posted, so the alarm
            // is not lost -- it just has to be tapped.
            Log.w(TAG, "background activity start blocked; notification only", e)
        }
    }
}
