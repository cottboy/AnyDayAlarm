package com.anyday.any_day_alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * AlarmManager 精确闹钟调度。
 * requestCode 用 alarmId.hashCode()，同一闹钟重复调度自然覆盖。
 */
object AlarmScheduler {
    const val ACTION_ALARM_FIRE = "any_day_alarm.ALARM_FIRE"
    const val EXTRA_ALARM_ID = "alarm_id"

    /** 系统默认铃声标识以外的内置铃声前缀 / 本地文件前缀，与 Dart 侧约定一致。 */
    const val RINGTONE_BUILTIN_PREFIX = "builtin:"
    const val RINGTONE_FILE_PREFIX = "file:"

    fun canScheduleExact(context: Context): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
    }

    private fun fireIntent(context: Context, alarmId: String): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java)
            .setAction(ACTION_ALARM_FIRE)
            .putExtra(EXTRA_ALARM_ID, alarmId)
        return PendingIntent.getBroadcast(
            context,
            alarmId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * 调度一次精确响铃。返回 true 表示精确调度成功；
     * 无精确权限时降级为 ±10 分钟窗口的近似调度（兜底，仍会响铃）。
     */
    fun schedule(context: Context, alarmId: String, triggerAtMillis: Long): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = fireIntent(context, alarmId)
        val exact = canScheduleExact(context)
        if (exact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        } else {
            am.setWindow(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                10 * 60 * 1000L,
                pi,
            )
        }
        return exact
    }

    fun cancel(context: Context, alarmId: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(fireIntent(context, alarmId))
    }

    /** 按当前调度文件全量重排：先取消全部，再逐条调度仍有效的下一次触发。 */
    fun rescheduleAll(context: Context): Boolean {
        val alarms = NativeAlarmStore.readAll(context)
        val now = System.currentTimeMillis()
        var allExact = true
        alarms.forEach { alarm ->
            cancel(context, alarm.id)
            if (alarm.enabled) {
                val next = alarm.computeNextTrigger()
                if (next != null && next > now) {
                    if (!schedule(context, alarm.id, next)) allExact = false
                }
            }
        }
        return allExact
    }
}
