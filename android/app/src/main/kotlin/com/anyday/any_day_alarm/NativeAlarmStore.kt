package com.anyday.any_day_alarm

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/**
 * 原生侧的闹钟调度数据。
 *
 * Flutter 每次闹钟变更后通过 syncAndScheduleAll 全量同步到这里：
 * 写入私有目录 JSON 文件（供开机重排 / 触发后兜底重排读取），并重排 AlarmManager。
 * 所有字段解析时都做校验，绝不信任文件内容。
 */
data class NativeAlarm(
    val id: String,
    val enabled: Boolean,
    val repeatType: Int, // 0=一次性 1=每天 2=每周自定义 3=每月 4=每年
    val triggerAt: Long?,
    val futureTriggers: List<Long>,
    val onceAt: Long?,
    val hour: Int,
    val minute: Int,
    val weekdays: List<Int>,
    val label: String,
    val ringtoneId: String,
    val vibrate: Boolean,
    val volumeRamp: Boolean,
    val snoozeMinutes: Int,
    val colorValue: Int,
) {
    /**
     * 按规则计算下一次触发时间（毫秒时间戳）。
     * 优先级：Flutter 同步的 triggerAt（仍有效时）→ futureTriggers 预计算数组
     * （农历/年月规则原生无法复算，由 Dart 侧预生成）→ 基础规则（每天/每周/一次性）兜底。
     */
    fun computeNextTrigger(now: Calendar = Calendar.getInstance()): Long? {
        val nowMillis = now.timeInMillis
        triggerAt?.takeIf { it > nowMillis }?.let { return it }
        futureTriggers.firstOrNull { it > nowMillis }?.let { return it }
        return when (repeatType) {
            0 -> onceAt?.takeIf { it > nowMillis }
            1 -> {
                var t = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                if (t.timeInMillis <= nowMillis) t.add(Calendar.DAY_OF_YEAR, 1)
                t.timeInMillis
            }
            2 -> {
                if (weekdays.isEmpty()) return null
                for (offset in 0..7) {
                    val t = (Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, hour)
                        set(Calendar.MINUTE, minute)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                        add(Calendar.DAY_OF_YEAR, offset)
                    })
                    // Calendar.DAY_OF_WEEK: 1=周日 … 7=周六；本地编码 1=周一 … 7=周日
                    val isoWeekday = when (t.get(Calendar.DAY_OF_WEEK)) {
                        Calendar.MONDAY -> 1
                        Calendar.TUESDAY -> 2
                        Calendar.WEDNESDAY -> 3
                        Calendar.THURSDAY -> 4
                        Calendar.FRIDAY -> 5
                        Calendar.SATURDAY -> 6
                        else -> 7
                    }
                    if (isoWeekday in weekdays && t.timeInMillis > nowMillis) return t.timeInMillis
                }
                null
            }
            else -> null
        }
    }

    companion object {
        /** 从同步 JSON 解析单条；任何字段非法即返回 null（安全第一）。 */
        fun fromJson(o: JSONObject): NativeAlarm? {
            try {
                val id = o.optString("id")
                if (id.isEmpty() || id.length > 64) return null
                val repeatType = o.optInt("repeatType", -1)
                if (repeatType !in 0..4) return null
                val hour = o.optInt("hour", -1)
                val minute = o.optInt("minute", -1)
                if (hour !in 0..23 || minute !in 0..59) return null
                val triggerAt = if (o.has("triggerAt") && !o.isNull("triggerAt")) o.getLong("triggerAt") else null
                val onceAt = if (o.has("onceAt") && !o.isNull("onceAt")) o.getLong("onceAt") else null
                val weekdays = mutableListOf<Int>()
                val arr = o.optJSONArray("weekdays")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val w = arr.optInt(i, -1)
                        if (w in 1..7) weekdays.add(w)
                    }
                }
                // Flutter 预计算的未来触发点：只保留合理范围内的正值并排序
                val futureTriggers = mutableListOf<Long>()
                val ft = o.optJSONArray("futureTriggers")
                if (ft != null) {
                    for (i in 0 until ft.length()) {
                        val v = ft.optLong(i, -1)
                        if (v > 0) futureTriggers.add(v)
                    }
                }
                return NativeAlarm(
                    id = id,
                    enabled = o.optBoolean("enabled", false),
                    repeatType = repeatType,
                    triggerAt = triggerAt,
                    futureTriggers = futureTriggers.distinct().sorted().take(10),
                    onceAt = onceAt,
                    hour = hour,
                    minute = minute,
                    weekdays = weekdays,
                    label = o.optString("label").take(100),
                    ringtoneId = o.optString("ringtoneId", "default").take(500),
                    vibrate = o.optBoolean("vibrate", true),
                    volumeRamp = o.optBoolean("volumeRamp", false),
                    snoozeMinutes = o.optInt("snoozeMinutes", 5).coerceIn(1, 60),
                    colorValue = o.optInt("colorValue", -1),
                )
            } catch (_: Exception) {
                return null
            }
        }
    }
}

/** 调度文件的读写。 */
object NativeAlarmStore {
    private const val FILE_NAME = "anyday_alarms.json"

    fun file(context: Context): File = File(context.filesDir, FILE_NAME)

    fun readAll(context: Context): List<NativeAlarm> {
        return try {
            val raw = file(context).takeIf { it.exists() }?.readText() ?: return emptyList()
            val arr = JSONArray(raw)
            (0 until arr.length())
                .mapNotNull { i ->
                    val o = arr.optJSONObject(i) ?: return@mapNotNull null
                    NativeAlarm.fromJson(o)
                }
                .distinctBy { it.id }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun writeAll(context: Context, alarms: List<NativeAlarm>) {
        try {
            val arr = JSONArray()
            alarms.forEach { a ->
                arr.put(
                    JSONObject().apply {
                        put("id", a.id)
                        put("enabled", a.enabled)
                        put("repeatType", a.repeatType)
                        put("triggerAt", a.triggerAt ?: JSONObject.NULL)
                        put("futureTriggers", JSONArray(a.futureTriggers))
                        put("onceAt", a.onceAt ?: JSONObject.NULL)
                        put("hour", a.hour)
                        put("minute", a.minute)
                        put("weekdays", JSONArray(a.weekdays))
                        put("label", a.label)
                        put("ringtoneId", a.ringtoneId)
                        put("vibrate", a.vibrate)
                        put("volumeRamp", a.volumeRamp)
                        put("snoozeMinutes", a.snoozeMinutes)
                        put("colorValue", a.colorValue)
                    }
                )
            }
            val tmp = File(context.filesDir, "$FILE_NAME.tmp")
            tmp.writeText(arr.toString())
            val target = file(context)
            if (!tmp.renameTo(target)) {
                // rename 失败（如目标已存在）时退化为直接写入
                target.writeText(arr.toString())
                tmp.delete()
            }
        } catch (_: Exception) {
            // 调度文件写失败不致命：调度已在内存完成，下次同步会重试
        }
    }

    fun find(context: Context, id: String): NativeAlarm? =
        readAll(context).firstOrNull { it.id == id }
}
