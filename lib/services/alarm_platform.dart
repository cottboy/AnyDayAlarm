import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/alarm.dart';

/// 与原生层（Android: AlarmManager；iOS: AlarmKit/通知）通信的唯一通道。
class AlarmPlatform {
  static const _channel = MethodChannel('any_day_alarm/native');

  /// 供原生回调的 MethodChannel（响铃事件等，方向：原生 → Flutter）。
  static const _eventCallbackChannel = MethodChannel('any_day_alarm/native_events');

  /// 把 Dart 侧注册的处理器挂到原生回调通道上。
  static void setEventHandler(Future<dynamic> Function(MethodCall call)? handler) {
    _eventCallbackChannel.setMethodCallHandler(handler);
  }

  /// 全量同步闹钟到原生：写入原生可读的调度文件并重排所有精确闹钟。
  /// [alarms] 中已启用且 [Alarm.nextTriggerAt] 非空的闹钟会被调度。
  /// 农历/年月规则的闹钟附带 [Alarm.futureTriggers] 预计算数组，
  /// 原生兜底重排时按数组顺延，无需理解农历。
  static Future<bool> syncAndScheduleAll(List<Alarm> alarms) async {
    final now = DateTime.now();
    final payload = alarms.map((a) {
      final next = a.enabled ? a.nextTriggerAt(now) : null;
      return <String, dynamic>{
        'id': a.id,
        'enabled': a.enabled,
        'repeatType': a.repeatType.index,
        'triggerAt': next?.millisecondsSinceEpoch,
        'futureTriggers': a.enabled ? a.futureTriggers() : const <int>[],
        'onceAt': a.onceDate != null
            ? DateTime(a.onceDate!.year, a.onceDate!.month, a.onceDate!.day, a.hour, a.minute)
                .millisecondsSinceEpoch
            : null,
        'hour': a.hour,
        'minute': a.minute,
        'weekdays': a.weekdays,
        'label': a.label,
        'ringtoneId': a.ringtoneId,
        'vibrate': a.vibrate,
        'volumeRamp': a.volumeRamp,
        'snoozeMinutes': a.snoozeMinutes,
        // ARGB 颜色转为有符号 32 位，供 Kotlin Int 直接使用
        'colorValue': a.colorValue.toSigned(32),
      };
    }).toList();
    try {
      return await _channel.invokeMethod<bool>('syncAndScheduleAll', jsonEncode(payload)) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> canScheduleExactAlarms() async =>
      await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;

  static Future<void> openExactAlarmSettings() async =>
      await _channel.invokeMethod('openExactAlarmSettings');

  static Future<bool> isIgnoringBatteryOptimizations() async =>
      await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;

  static Future<void> requestIgnoreBatteryOptimizations() async =>
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');

  static Future<bool> areNotificationsEnabled() async =>
      await _channel.invokeMethod<bool>('areNotificationsEnabled') ?? true;

  static Future<void> openNotificationSettings() async =>
      await _channel.invokeMethod('openNotificationSettings');

  /// 当前是否有正在响铃的闹钟（冷启动后拉取，用于恢复响铃页）。
  static Future<String?> pendingRingingAlarm() async =>
      await _channel.invokeMethod<String>('pendingRingingAlarm');

  static Future<void> stopRinging(String alarmId) async =>
      await _channel.invokeMethod('stopRinging', alarmId);

  /// 贪睡：停止当前响铃并在 [minutes] 分钟后再次触发同一闹钟。
  static Future<void> snoozeRinging(String alarmId, int minutes) async =>
      await _channel.invokeMethod('snoozeRinging', <String, dynamic>{'id': alarmId, 'minutes': minutes});

  /// 铃声试听（编辑页）。
  static Future<void> playRingtonePreview(String ringtoneId) async =>
      await _channel.invokeMethod('playRingtonePreview', ringtoneId);

  static Future<void> stopRingtonePreview() async =>
      await _channel.invokeMethod('stopRingtonePreview');

  /// 通过系统文件选择器挑选本地音频，复制到应用私有目录后返回路径；取消返回 null。
  static Future<Map<String, String>?> pickRingtone() async {
    final result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('pickRingtone')
        .catchError((_) => null);
    if (result == null) return null;
    final path = result['path'];
    final name = result['name'];
    if (path is! String || name is! String) return null;
    return {'path': path, 'name': name};
  }
}

/// 内置铃声（与 android/app/src/main/res/raw 下同名 .wav 一一对应）。
class BuiltinRingtone {
  final String id;
  final String fileKey;

  const BuiltinRingtone({required this.id, required this.fileKey});
}

class RingtoneCatalog {
  static const builtin = <BuiltinRingtone>[
    BuiltinRingtone(id: 'builtin:classic', fileKey: 'classic'),
    BuiltinRingtone(id: 'builtin:digital', fileKey: 'digital'),
    BuiltinRingtone(id: 'builtin:chime', fileKey: 'chime'),
    BuiltinRingtone(id: 'builtin:rise', fileKey: 'rise'),
  ];

  /// 编辑页标签颜色选择项。
  static const labelColors = <int>[
    0xFF4F8CFF,
    0xFF34C77B,
    0xFFFF9F43,
    0xFFE85A6B,
    0xFF9B6CFF,
    0xFF2BC0C9,
  ];
}
