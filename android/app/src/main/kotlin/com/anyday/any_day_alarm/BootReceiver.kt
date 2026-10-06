package com.anyday.any_day_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** 开机完成 / 应用被更新后重排全部闹钟（AlarmManager 注册在重启后会丢失）。 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AnyDayAlarm"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        try {
            AlarmScheduler.rescheduleAll(context)
        } catch (e: Exception) {
            Log.e(TAG, "reschedule after boot failed", e)
        }
    }
}
