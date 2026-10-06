import 'dart:math';

import '../lunar/lunar_helper.dart';

/// 重复类型（按触发间隔从小到大；枚举顺序即 JSON 序列化 index）
enum RepeatType { once, daily, weekly, monthly, yearly }

/// 日期基准：公历 / 农历（once / yearly / monthly 可选，daily / weekly 恒为公历）
enum CalendarType { solar, lunar }

/// 闹钟实体。
///
/// 调度的统一抽象：调度器只关心 [nextTriggerAt] 算出的下一个时间点。
/// 农历规则（闰月、三十缺失）的换算统一委托 [LunarHelper]。
class Alarm {
  Alarm({
    required this.id,
    required this.label,
    required this.repeatType,
    this.calendar = CalendarType.solar,
    this.onceDate,
    required this.hour,
    required this.minute,
    List<int>? weekdays,
    this.solarMonth,
    this.solarDay,
    this.lunarMonth,
    this.isLeapMonth = false,
    this.lunarDay,
    this.ringtoneId = 'default',
    this.vibrate = true,
    this.volumeRamp = false,
    this.snoozeMinutes = 5,
    this.snoozeCount = 3,
    this.colorValue = 0xFF4F8CFF,
    this.enabled = true,
  }) : weekdays = weekdays ?? const [];

  String id;
  String label;
  RepeatType repeatType;

  /// 日期基准（once / yearly / monthly 时有意义）
  CalendarType calendar;

  /// 一次性闹钟的触发日期（公历；农历 once 在编辑时已换算成公历，
  /// calendar 仅决定列表中的显示表述）
  DateTime? onceDate;

  int hour;
  int minute;

  /// 每周重复的星期，ISO 编码：1=周一 … 7=周日（仅 [RepeatType.weekly] 时有效）
  List<int> weekdays;

  /// 每年/每月重复的公历月日（yearly 用月+日，monthly 只用日）
  int? solarMonth;
  int? solarDay;

  /// 每年/每月重复的农历月日（闰月通过 [isLeapMonth] 标记）
  int? lunarMonth;
  bool isLeapMonth;
  int? lunarDay;

  /// 铃声标识：`default` | `builtin:<名称>` | `file:<绝对路径>`
  String ringtoneId;

  bool vibrate;

  /// 音量渐强：从静音逐步增强，避免瞬间惊醒
  bool volumeRamp;

  /// 贪睡间隔（分钟），snoozeCount 为 0 表示不允许贪睡
  int snoozeMinutes;
  int snoozeCount;

  /// 标签颜色（ARGB）
  int colorValue;

  bool enabled;

  static final Random _random = Random.secure();

  static String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16)}';
  }

  Alarm copyWith({
    String? label,
    RepeatType? repeatType,
    CalendarType? calendar,
    DateTime? onceDate,
    bool clearOnceDate = false,
    int? hour,
    int? minute,
    List<int>? weekdays,
    int? solarMonth,
    int? solarDay,
    int? lunarMonth,
    bool? isLeapMonth,
    int? lunarDay,
    String? ringtoneId,
    bool? vibrate,
    bool? volumeRamp,
    int? snoozeMinutes,
    int? snoozeCount,
    int? colorValue,
    bool? enabled,
  }) {
    return Alarm(
      id: id,
      label: label ?? this.label,
      repeatType: repeatType ?? this.repeatType,
      calendar: calendar ?? this.calendar,
      onceDate: clearOnceDate ? null : (onceDate ?? this.onceDate),
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      solarMonth: solarMonth ?? this.solarMonth,
      solarDay: solarDay ?? this.solarDay,
      lunarMonth: lunarMonth ?? this.lunarMonth,
      isLeapMonth: isLeapMonth ?? this.isLeapMonth,
      lunarDay: lunarDay ?? this.lunarDay,
      ringtoneId: ringtoneId ?? this.ringtoneId,
      vibrate: vibrate ?? this.vibrate,
      volumeRamp: volumeRamp ?? this.volumeRamp,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      colorValue: colorValue ?? this.colorValue,
      enabled: enabled ?? this.enabled,
    );
  }

  /// 计算下一次触发时间；已过期或无法触发时返回 null。
  DateTime? nextTriggerAt(DateTime now) {
    switch (repeatType) {
      case RepeatType.once:
        final d = onceDate;
        if (d == null) return null;
        final t = DateTime(d.year, d.month, d.day, hour, minute);
        return t.isAfter(now) ? t : null;
      case RepeatType.daily:
        var t = DateTime(now.year, now.month, now.day, hour, minute);
        if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
        return t;
      case RepeatType.weekly:
        if (weekdays.isEmpty) return null;
        final today = DateTime(now.year, now.month, now.day);
        for (var i = 0; i < 8; i++) {
          final day = today.add(Duration(days: i));
          if (weekdays.contains(day.weekday)) {
            final t = DateTime(day.year, day.month, day.day, hour, minute);
            if (t.isAfter(now)) return t;
          }
        }
        return null;
      case RepeatType.yearly:
        if (calendar == CalendarType.lunar) {
          final m = lunarMonth;
          final d = lunarDay;
          if (m == null || d == null) return null;
          return LunarHelper.nextLunarYearly(m, isLeapMonth, d, now, hour, minute);
        }
        final m = solarMonth;
        final d = solarDay;
        if (m == null || d == null) return null;
        return LunarHelper.nextSolarYearly(m, d, now, hour, minute);
      case RepeatType.monthly:
        if (calendar == CalendarType.lunar) {
          final d = lunarDay;
          if (d == null) return null;
          return LunarHelper.nextLunarMonthly(d, now, hour, minute);
        }
        final d = solarDay;
        if (d == null) return null;
        return LunarHelper.nextSolarMonthly(d, now, hour, minute);
    }
  }

  /// 未来 [count] 次触发时间戳（毫秒），随调度同步下发给原生层做兜底重排，
  /// 使原生侧无需理解农历规则。
  List<int> futureTriggers({int count = 3}) {
    final now = DateTime.now();
    final result = <int>[];
    var cursor = now;
    for (var i = 0; i < count; i++) {
      final t = nextTriggerAt(cursor);
      if (t == null) break;
      result.add(t.millisecondsSinceEpoch);
      cursor = t.add(const Duration(minutes: 1));
    }
    return result;
  }

  // ---- JSON 序列化（本地持久化，shared_preferences 内为可信来源；
  //      解析时对所有字段做类型与范围校验，防御脏数据） ----

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'repeatType': repeatType.index,
        'calendar': calendar.index,
        'onceDate': onceDate?.toIso8601String(),
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays,
        'solarMonth': solarMonth,
        'solarDay': solarDay,
        'lunarMonth': lunarMonth,
        'isLeapMonth': isLeapMonth,
        'lunarDay': lunarDay,
        'ringtoneId': ringtoneId,
        'vibrate': vibrate,
        'volumeRamp': volumeRamp,
        'snoozeMinutes': snoozeMinutes,
        'snoozeCount': snoozeCount,
        'colorValue': colorValue,
        'enabled': enabled,
      };

  static Alarm? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'];
      if (id is! String || id.isEmpty || id.length > 64) return null;
      final repeatIdx = json['repeatType'];
      final repeatType = repeatIdx is int && repeatIdx >= 0 && repeatIdx < RepeatType.values.length
          ? RepeatType.values[repeatIdx]
          : null;
      if (repeatType == null) return null;
      final hour = json['hour'];
      final minute = json['minute'];
      if (hour is! int || hour < 0 || hour > 23) return null;
      if (minute is! int || minute < 0 || minute > 59) return null;
      final calendarIdx = json['calendar'];
      final calendar = calendarIdx is int && calendarIdx >= 0 && calendarIdx < CalendarType.values.length
          ? CalendarType.values[calendarIdx]
          : CalendarType.solar;
      return Alarm(
        id: id,
        label: json['label'] is String ? (json['label'] as String).substring(0, min((json['label'] as String).length, 100)) : '',
        repeatType: repeatType,
        calendar: calendar,
        onceDate: DateTime.tryParse(json['onceDate'] as String? ?? ''),
        hour: hour,
        minute: minute,
        weekdays: (json['weekdays'] as List<dynamic>? ?? const [])
            .whereType<int>()
            .where((w) => w >= 1 && w <= 7)
            .toList(),
        solarMonth: _clampInt(json['solarMonth'], 1, 12),
        solarDay: _clampInt(json['solarDay'], 1, 31),
        lunarMonth: _clampInt(json['lunarMonth'], 1, 12),
        isLeapMonth: json['isLeapMonth'] is bool ? json['isLeapMonth'] as bool : false,
        lunarDay: _clampInt(json['lunarDay'], 1, 30),
        ringtoneId: json['ringtoneId'] is String ? json['ringtoneId'] as String : 'default',
        vibrate: json['vibrate'] is bool ? json['vibrate'] as bool : true,
        volumeRamp: json['volumeRamp'] is bool ? json['volumeRamp'] as bool : false,
        snoozeMinutes: json['snoozeMinutes'] is int ? (json['snoozeMinutes'] as int).clamp(1, 60) : 5,
        snoozeCount: json['snoozeCount'] is int ? (json['snoozeCount'] as int).clamp(0, 20) : 3,
        colorValue: json['colorValue'] is int ? json['colorValue'] as int : 0xFF4F8CFF,
        enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      );
    } catch (_) {
      return null;
    }
  }

  /// 可空整数字段的范围校验：非法值归为 null。
  static int? _clampInt(dynamic v, int min, int max) {
    if (v is! int) return null;
    return v >= min && v <= max ? v : null;
  }
}
