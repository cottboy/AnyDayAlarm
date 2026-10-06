package com.anyday.any_day_alarm

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Application：持有 Flutter 引擎引用，
 * 把"开始响铃"事件推送给 Flutter（进程存活时）；冷启动场景由
 * pendingRingingAlarm 拉取兜底。
 */
class App : Application() {
    companion object {
        private const val EVENT_CHANNEL = "any_day_alarm/native_events"
    }

    private var engine: FlutterEngine? = null

    fun attachEngine(newEngine: FlutterEngine) {
        engine = newEngine
    }

    fun detachEngine(oldEngine: FlutterEngine) {
        if (engine === oldEngine) engine = null
    }

    fun notifyRinging(alarmId: String) {
        val current = engine ?: return
        try {
            MethodChannel(current.dartExecutor.binaryMessenger, EVENT_CHANNEL)
                .invokeMethod("onAlarmRing", alarmId)
        } catch (_: Exception) {
            // Flutter 侧尚未就绪（冷启动中），响铃页由 pendingRingingAlarm 兜底拉起
        }
    }
}
