package com.anyday.any_day_alarm

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Flutter 宿主 Activity，同时是 Flutter ↔ 原生的方法通道中枢：
 * 调度同步、权限检查与跳转、铃声预览/挑选，以及响铃意图的路由。
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "AnyDayAlarm"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_FROM_ALARM = "from_alarm"

        private const val NATIVE_CHANNEL = "any_day_alarm/native"
        private const val REQ_PICK_RINGTONE = 4711
        private const val MAX_RINGTONE_BYTES = 15L * 1024 * 1024
        private const val MAX_LABEL_LENGTH = 100
        private const val PREFS_STABILITY = "stability"
        private const val KEY_BATTERY_ASKED = "battery_whitelist_asked"

        /**
         * 国产 ROM 自启动设置页（包名 to 类名）。
         * 自启动没有公开 API，只能逐个尝试跳转，全部失败时兜底到应用详情页。
         */
        private val AUTO_START_PAGES = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            "com.meizu.safe" to "com.meizu.safe.permission.SmartBGActivity",
        )

        /** 已知会拦截后台拉起的主流厂商关键字（自启动引导仅对这些机型展示）。 */
        private val AUTO_START_VENDOR_KEYS = setOf(
            "xiaomi", "redmi", "huawei", "honor", "oppo", "oneplus", "realme",
            "vivo", "iqoo", "meizu", "letv", "nubia",
        )
    }

    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        (applicationContext as App).attachEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    handleMethodCall(call, result)
                } catch (e: Exception) {
                    Log.e(TAG, "method ${call.method} failed", e)
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        (applicationContext as App).detachEngine(flutterEngine)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
        requestNotificationPermissionIfNeeded()
        requestBatteryWhitelistOnFirstRun()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    override fun onDestroy() {
        pendingPickResult = null
        super.onDestroy()
    }

    /** 响铃的全屏意图进入：允许锁屏上显示并点亮屏幕，然后通知 Flutter 弹响铃页。 */
    private fun handleAlarmIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_FROM_ALARM, false) != true) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        val alarmId = intent.getStringExtra(EXTRA_ALARM_ID)
        if (!alarmId.isNullOrEmpty()) {
            (applicationContext as App).notifyRinging(alarmId)
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    100,
                )
            }
        }
    }

    /**
     * 首次启动时主动弹出电池优化白名单的系统对话框（仅一次）。
     * 闹钟属于 Doze 下仍需准点触发的场景，白名单是官方认可的做法；
     * 用户拒绝后首页横幅仍可再次引导。
     */
    private fun requestBatteryWhitelistOnFirstRun() {
        val prefs = getSharedPreferences(PREFS_STABILITY, MODE_PRIVATE)
        if (prefs.getBoolean(KEY_BATTERY_ASKED, false)) return
        prefs.edit().putBoolean(KEY_BATTERY_ASKED, true).apply()
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName"))
            )
        } catch (e: Exception) {
            Log.w(TAG, "first-run battery whitelist request not available", e)
        }
    }

    private fun isAutoStartVendor(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return AUTO_START_VENDOR_KEYS.any { manufacturer.contains(it) }
    }

    /** 逐个尝试跳转厂商自启动设置页，成功返回 true。 */
    private fun tryOpenAutoStartPage(): Boolean {
        for ((pkg, cls) in AUTO_START_PAGES) {
            try {
                startActivity(
                    Intent()
                        .setClassName(pkg, cls)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return true
            } catch (_: Exception) {
                // 该厂商页面不存在，尝试下一个
            }
        }
        return false
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncAndScheduleAll" -> {
                val json = call.arguments as? String
                if (json.isNullOrEmpty() || json.length > 512 * 1024) {
                    result.error("BAD_ARGS", "invalid payload", null)
                    return
                }
                NativeAlarmStore.writeAll(this, NativeAlarmStoreParser.parse(json))
                result.success(AlarmScheduler.rescheduleAll(this))
            }
            "canScheduleExactAlarms" -> result.success(AlarmScheduler.canScheduleExact(this))
            "openExactAlarmSettings" -> {
                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                } else {
                    Intent(Settings.ACTION_SETTINGS)
                }
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                result.success(null)
            }
            "isIgnoringBatteryOptimizations" -> {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(packageName))
            }
            "requestIgnoreBatteryOptimizations" -> {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.w(TAG, "battery optimization request not available", e)
                }
                result.success(null)
            }
            "areNotificationsEnabled" -> {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                result.success(nm.areNotificationsEnabled())
            }
            "openNotificationSettings" -> {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                startActivity(intent)
                result.success(null)
            }
            "canUseFullScreenIntent" -> {
                // Android 14+ 全屏意图可能被用户在通知设置中撤销（侧载默认也可能不授予）
                result.success(
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
                    } else {
                        true
                    }
                )
            }
            "needsAutoStartGuide" -> result.success(isAutoStartVendor())
            "openAutoStartSettings" -> {
                if (!tryOpenAutoStartPage()) {
                    // 兜底：应用详情页，用户可从"通知/电池"入口自行寻找自启动开关
                    try {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(Uri.parse("package:$packageName"))
                        )
                    } catch (e: Exception) {
                        Log.w(TAG, "cannot open app details", e)
                    }
                }
                result.success(null)
            }
            "pendingRingingAlarm" -> result.success(AlarmRingService.currentAlarmId.get())
            "stopRinging" -> {
                val alarmId = call.arguments as? String
                if (alarmId.isNullOrEmpty() || alarmId != AlarmRingService.currentAlarmId.get()) {
                    result.success(null)
                    return
                }
                startService(
                    ringServiceIntent(AlarmRingService.ACTION_STOP)
                        .putExtra(AlarmRingService.EXTRA_ALARM_ID, alarmId)
                )
                result.success(null)
            }
            "snoozeRinging" -> {
                val args = call.arguments as? Map<*, *>
                val alarmId = args?.get("id") as? String
                val minutes = (args?.get("minutes") as? Int) ?: 5
                if (alarmId.isNullOrEmpty() || alarmId != AlarmRingService.currentAlarmId.get() ||
                    minutes !in 1..60
                ) {
                    result.error("BAD_ARGS", "invalid snooze args", null)
                    return
                }
                startService(
                    ringServiceIntent(AlarmRingService.ACTION_SNOOZE)
                        .putExtra(AlarmRingService.EXTRA_ALARM_ID, alarmId)
                        .putExtra(AlarmRingService.EXTRA_SNOOZE_MINUTES, minutes)
                )
                result.success(null)
            }
            "playRingtonePreview" -> {
                val ringtoneId = call.arguments as? String
                if (ringtoneId != null && ringtoneId.length <= 500) {
                    RingtonePreviewPlayer.start(this, ringtoneId)
                }
                result.success(null)
            }
            "stopRingtonePreview" -> {
                RingtonePreviewPlayer.stop()
                result.success(null)
            }
            "pickRingtone" -> startRingtonePicker(result)
            else -> result.notImplemented()
        }
    }

    private fun ringServiceIntent(action: String): Intent =
        Intent(this, AlarmRingService::class.java).setAction(action)

    private fun startRingtonePicker(result: MethodChannel.Result) {
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
        }
        try {
            startActivityForResult(intent, REQ_PICK_RINGTONE)
        } catch (e: Exception) {
            pendingPickResult = null
            result.success(null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_PICK_RINGTONE) {
            val callback = pendingPickResult
            pendingPickResult = null
            if (callback == null) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                callback.success(null)
                return
            }
            try {
                callback.success(copyPickedRingtone(uri))
            } catch (e: Exception) {
                Log.e(TAG, "copy ringtone failed", e)
                callback.error("PICK_FAILED", e.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** 把用户挑选的音频复制进应用私有铃声目录，杜绝直接引用外部路径。 */
    private fun copyPickedRingtone(uri: Uri): Map<String, String> {
        val displayName = queryDisplayName(uri) ?: "ringtone"
        contentResolver.openInputStream(uri)?.use { input ->
            val dir = File(filesDir, "ringtones")
            if (!dir.exists() && !dir.mkdirs()) throw IOException("cannot create ringtone dir")
            val target = File(dir, "ring_${System.currentTimeMillis()}.bin")
            var copied = 0L
            val buf = ByteArray(64 * 1024)
            target.outputStream().use { output ->
                while (true) {
                    val read = input.read(buf)
                    if (read == -1) break
                    copied += read
                    if (copied > MAX_RINGTONE_BYTES) throw IOException("file too large")
                    output.write(buf, 0, read)
                }
            }
            return mapOf("path" to target.absolutePath, "name" to displayName.take(MAX_LABEL_LENGTH))
        } ?: throw IOException("cannot open selected file")
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
            }
        } catch (_: Exception) {
            null
        }
    }
}

/** 独立的解析辅助：JSON → NativeAlarm 列表，全部数据视为不可信输入。 */
private object NativeAlarmStoreParser {
    fun parse(json: String): List<NativeAlarm> {
        return try {
            val arr = org.json.JSONArray(json)
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
}

/** 铃声试听播放器（编辑页），与响铃播放完全隔离。 */
private object RingtonePreviewPlayer {
    private const val TAG = "AnyDayAlarm"
    private var player: android.media.MediaPlayer? = null

    fun start(context: Context, ringtoneId: String) {
        stop()
        try {
            val uri = resolvePreviewUri(context, ringtoneId) ?: return
            player = android.media.MediaPlayer().apply {
                setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(context, uri)
                isLooping = false
                prepare()
                setOnCompletionListener {
                    stop()
                }
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "preview failed: $ringtoneId", e)
            stop()
        }
    }

    private fun resolvePreviewUri(context: Context, ringtoneId: String): Uri? {
        return when {
            ringtoneId.startsWith(AlarmScheduler.RINGTONE_BUILTIN_PREFIX) -> {
                val key = ringtoneId.removePrefix(AlarmScheduler.RINGTONE_BUILTIN_PREFIX)
                val resId = context.resources.getIdentifier(key, "raw", context.packageName)
                if (resId != 0) Uri.parse("android.resource://${context.packageName}/$resId") else null
            }
            ringtoneId.startsWith(AlarmScheduler.RINGTONE_FILE_PREFIX) -> {
                val path = ringtoneId.removePrefix(AlarmScheduler.RINGTONE_FILE_PREFIX)
                val dir = File(context.filesDir, "ringtones")
                val f = File(path)
                if (f.exists() && f.canonicalPath.startsWith(dir.canonicalPath + File.separator)) {
                    Uri.fromFile(f)
                } else null
            }
            else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        }
    }

    fun stop() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
    }
}
