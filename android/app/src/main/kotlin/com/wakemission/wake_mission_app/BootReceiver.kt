package com.wakemission.wake_mission_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Puts the native rings back after a reboot or an app update.
 *
 * Android clears every AlarmManager entry on both. The Dart alarms return via
 * the alarm plugin's own reboot receiver, but the alarms that launch the
 * ringing screen over whatever is on top are ours, so restoring them is ours
 * too -- without this a phone that was off overnight only rang once the
 * student happened to open the app.
 *
 * Deliberately not direct-boot aware: the records live in normal (credential
 * encrypted) storage, which is unreadable until the first unlock. BOOT_COMPLETED
 * arrives after that, which is early enough for an alarm hours away.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i("WakeForceRing", "restoring native rings after ${intent.action}")
                RingAlarmReceiver.restoreAll(context)
            }
        }
    }
}
