package com.anyday.any_day_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * 精确闹钟触发入口：启动响铃服务，并为重复闹钟立即排定下一次，
 * 不依赖 Flutter 侧存活，保证任何场景下不丢闹钟。
 */
class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AnyDayAlarm"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_ALARM_FIRE) return
        val alarmId = intent.getStringExtra(AlarmScheduler.EXTRA_ALARM_ID) ?: return
        if (alarmId.length > 64) return

        val alarm = NativeAlarmStore.find(context, alarmId)
        if (alarm == null) {
            Log.w(TAG, "triggered alarm not found in store: $alarmId")
            return
        }

        try {
            val service = Intent(context, AlarmRingService::class.java)
                .putExtra(AlarmRingService.EXTRA_ALARM_ID, alarm.id)
                .putExtra(AlarmRingService.EXTRA_LABEL, alarm.label)
                .putExtra(AlarmRingService.EXTRA_RINGTONE_ID, alarm.ringtoneId)
                .putExtra(AlarmRingService.EXTRA_VIBRATE, alarm.vibrate)
                .putExtra(AlarmRingService.EXTRA_VOLUME_RAMP, alarm.volumeRamp)
                .putExtra(AlarmRingService.EXTRA_SNOOZE_MINUTES, alarm.snoozeMinutes)
                .putExtra(AlarmRingService.EXTRA_COLOR_VALUE, alarm.colorValue)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        } catch (e: Exception) {
            // 前台服务启动失败（系统限制等）时响铃通知仍会通过服务兜底重试一次
            Log.e(TAG, "failed to start ring service", e)
        }

        // 重复闹钟：立即排下一次，与 Flutter 是否存活无关
        if (alarm.repeatType != 0) {
            val next = alarm.computeNextTrigger()
            if (next != null) {
                AlarmScheduler.schedule(context, alarm.id, next)
            }
        }
    }
}
