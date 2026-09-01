package com.wakemission.wake_mission_app

import android.content.Context
import android.media.AudioManager
import android.util.Log

/**
 * Forces the alarm stream to full while a ring is going, and puts it back
 * afterwards.
 *
 * A student who turned the alarm volume down to study the night before will
 * otherwise sleep through the alarm that was supposed to wake them -- which
 * is the one failure this app cannot have. Only the alarm stream is touched;
 * ring, media and notification volumes are left alone.
 *
 * [previous] is shared, so the service and the ringing screen can both ask
 * without either of them clobbering the value the other saved: the first
 * boost records the real level and the last restore puts it back.
 */
object AlarmVolume {
    private const val TAG = "WakeForceRing"
    private var previous: Int? = null

    fun boost(context: Context) {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (previous == null) {
                previous = am.getStreamVolume(AudioManager.STREAM_ALARM)
            }
            am.setStreamVolume(
                AudioManager.STREAM_ALARM,
                am.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0,
            )
            Log.i(TAG, "alarm volume raised (was $previous)")
        } catch (e: Exception) {
            // Do Not Disturb can refuse a volume change. Not worth failing the
            // alarm over -- it just rings at whatever the phone was set to.
            Log.w(TAG, "could not raise alarm volume", e)
        }
    }

    fun restore(context: Context) {
        val level = previous ?: return
        previous = null
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.setStreamVolume(AudioManager.STREAM_ALARM, level, 0)
            Log.i(TAG, "alarm volume restored to $level")
        } catch (e: Exception) {
            Log.w(TAG, "could not restore alarm volume", e)
        }
    }
}
