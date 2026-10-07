package com.anyday.any_day_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 系统事件后重排全部闹钟：
 * - 开机 / 应用被更新：AlarmManager 注册在重启后会丢失，必须重建；
 * - 系统时间被手动修改 / 时区变化：清理已过期或错位的触发点，
 *   避免回拨时间后误触发、前调时间后长时间不响。
 * 复杂规则（农历/周几等）的重算由下次打开应用时 Flutter 全量同步兜底，
 * 这里只做原生存储内的快速修正。
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AnyDayAlarm"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_TIME_CHANGED &&
            action != Intent.ACTION_TIMEZONE_CHANGED
        ) return
        try {
            AlarmScheduler.rescheduleAll(context)
        } catch (e: Exception) {
            Log.e(TAG, "reschedule after system event ($action) failed", e)
        }
    }
}
