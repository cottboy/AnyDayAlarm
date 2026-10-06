package com.anyday.any_day_alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import java.io.File
import java.util.concurrent.atomic.AtomicReference

/**
 * 响铃前台服务：铃声 + 震动 + 全屏意图通知。
 * 与响铃 UI 解耦——即使 Flutter 页面没有弹出，铃声也照常响起；
 * 超时自动停止，避免无人处理时一直响到没电。
 */
class AlarmRingService : Service() {
    companion object {
        private const val TAG = "AnyDayAlarm"
        private const val CHANNEL_ID = "anyday_alarm_ring"
        private const val NOTIFICATION_ID = 1001

        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_LABEL = "label"
        const val EXTRA_RINGTONE_ID = "ringtone_id"
        const val EXTRA_VIBRATE = "vibrate"
        const val EXTRA_VOLUME_RAMP = "volume_ramp"
        const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"
        const val EXTRA_COLOR_VALUE = "color_value"

        const val ACTION_STOP = "any_day_alarm.STOP_RING"
        const val ACTION_SNOOZE = "any_day_alarm.SNOOZE_RING"

        private val RINGTONE_BUILTIN_KEYS = setOf("classic", "digital", "chime", "rise")

        /** 当前正在响铃的闹钟（供 Flutter 冷启动后拉取）。 */
        val currentAlarmId = AtomicReference<String?>(null)

        private const val TIMEOUT_MILLIS = 5 * 60 * 1000L
        private const val RAMP_DURATION_MILLIS = 60 * 1000L
        private const val RAMP_STEP_MILLIS = 500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var alarmId: String? = null
    private var snoozeMinutes = 5

    private val timeoutRunnable = Runnable {
        Log.i(TAG, "ringing timeout, auto stop")
        stopRingingInternal()
    }
    private val rampRunnable = object : Runnable {
        override fun run() {
            val p = player ?: return
            val elapsed = System.currentTimeMillis() - rampStart
            val fraction = (elapsed.toFloat() / RAMP_DURATION_MILLIS).coerceIn(0f, 1f)
            try {
                p.setVolume(fraction, fraction)
            } catch (_: Exception) {
            }
            if (fraction < 1f) handler.postDelayed(this, RAMP_STEP_MILLIS)
        }
    }
    private var rampStart = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRingingInternal()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                val id = alarmId
                if (id != null) {
                    val minutes = (intent.getIntExtra(EXTRA_SNOOZE_MINUTES, snoozeMinutes)).coerceIn(1, 60)
                    val at = System.currentTimeMillis() + minutes * 60_000L
                    AlarmScheduler.schedule(this, id, at)
                }
                stopRingingInternal()
                return START_NOT_STICKY
            }
        }

        val id = intent?.getStringExtra(EXTRA_ALARM_ID)
        if (id.isNullOrEmpty() || id.length > 64) {
            stopSelf()
            return START_NOT_STICKY
        }
        alarmId = id
        currentAlarmId.set(id)
        snoozeMinutes = intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 5).coerceIn(1, 60)

        val label = intent.getStringExtra(EXTRA_LABEL).orEmpty().take(100)
        val ringtoneId = intent.getStringExtra(EXTRA_RINGTONE_ID) ?: "default"
        val vibrate = intent.getBooleanExtra(EXTRA_VIBRATE, true)
        val volumeRamp = intent.getBooleanExtra(EXTRA_VOLUME_RAMP, false)
        val colorValue = intent.getIntExtra(EXTRA_COLOR_VALUE, -1)

        startRingNotification(label, colorValue)
        startSound(ringtoneId, volumeRamp)
        if (vibrate) startVibration()
        acquireWakeLock()
        handler.postDelayed(timeoutRunnable, TIMEOUT_MILLIS)

        // 通知 Flutter 侧弹响铃页（冷启动场景由 pendingRingingAlarm 拉取兜底）
        (applicationContext as App).notifyRinging(id)

        return START_NOT_STICKY
    }

    private fun startRingNotification(label: String, colorValue: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.ring_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = getString(R.string.ring_channel_desc)
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(channel)
        }

        val launch = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
            putExtra(MainActivity.EXTRA_FROM_ALARM, true)
        }
        val fullScreen = PendingIntent.getActivity(
            this,
            (alarmId ?: "").hashCode() + 7,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = label.ifEmpty { getString(R.string.ring_default_title) }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle(title)
            .setContentText(getString(R.string.ring_notification_text))
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setOnlyAlertOnce(false)
            .setAutoCancel(false)
            .setColor(colorValue.takeIf { it != -1 } ?: 0)
            .setContentIntent(fullScreen)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            builder.setFullScreenIntent(fullScreen, true)
        }

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun resolveAlarmUri(ringtoneId: String): android.net.Uri {
        val resolved = when {
            ringtoneId.startsWith(AlarmScheduler.RINGTONE_BUILTIN_PREFIX) -> {
                val key = ringtoneId.removePrefix(AlarmScheduler.RINGTONE_BUILTIN_PREFIX)
                if (key in RINGTONE_BUILTIN_KEYS) {
                    val resId = resources.getIdentifier(key, "raw", packageName)
                    if (resId != 0) android.net.Uri.parse("android.resource://$packageName/$resId") else null
                } else null
            }
            ringtoneId.startsWith(AlarmScheduler.RINGTONE_FILE_PREFIX) -> {
                // 仅允许播放复制到应用私有铃声目录内的文件，拒绝任意路径
                val path = ringtoneId.removePrefix(AlarmScheduler.RINGTONE_FILE_PREFIX)
                val ringtoneDir = File(filesDir, "ringtones")
                val f = File(path)
                if (f.exists() && f.canonicalPath.startsWith(ringtoneDir.canonicalPath + File.separator)) {
                    android.net.Uri.fromFile(f)
                } else null
            }
            else -> null
        }
        if (resolved != null) return resolved
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
    }

    private fun startSound(ringtoneId: String, volumeRamp: Boolean) {
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(applicationContext, resolveAlarmUri(ringtoneId))
                isLooping = true
                if (volumeRamp) {
                    setVolume(0f, 0f)
                } else {
                    setVolume(1f, 1f)
                }
                prepare()
                start()
            }
            if (volumeRamp) {
                rampStart = System.currentTimeMillis()
                handler.postDelayed(rampRunnable, RAMP_STEP_MILLIS)
            }
        } catch (e: Exception) {
            Log.e(TAG, "play ringtone failed: $ringtoneId", e)
            player?.release()
            player = null
        }
    }

    private fun startVibration() {
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val effect = VibrationEffect.createWaveform(longArrayOf(0, 600, 400), 0)
            vib.vibrate(effect)
            vibrator = vib
        } catch (e: Exception) {
            Log.e(TAG, "vibration failed", e)
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "any_day_alarm:ring")
            wakeLock?.setReferenceCounted(false)
            wakeLock?.acquire(TIMEOUT_MILLIS)
        } catch (_: Exception) {
        }
    }

    private fun stopRingingInternal() {
        handler.removeCallbacksAndMessages(null)
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
        try {
            wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        currentAlarmId.set(null)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        // onStartCommand 之外异常终止时也保证资源释放
        if (currentAlarmId.get() != null) {
            handler.removeCallbacksAndMessages(null)
            try {
                player?.stop()
                player?.release()
            } catch (_: Exception) {
            }
            player = null
            try {
                vibrator?.cancel()
            } catch (_: Exception) {
            }
            vibrator = null
            try {
                wakeLock?.release()
            } catch (_: Exception) {
            }
            wakeLock = null
            currentAlarmId.set(null)
        }
        super.onDestroy()
    }
}
