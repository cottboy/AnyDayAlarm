import 'package:flutter_test/flutter_test.dart';

import 'package:any_day_alarm/models/alarm.dart';

void main() {
  group('Alarm.nextTriggerAt', () {
    test('一次性闹钟：未来时间返回该时间点，过期返回 null', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final alarm = Alarm(
        id: 'a1',
        label: '会议',
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 11, 6),
        hour: 9,
        minute: 30,
      );
      expect(
        alarm.nextTriggerAt(now),
        DateTime(2026, 11, 6, 9, 30),
      );

      final past = Alarm(
        id: 'a2',
        label: '过期',
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 10, 1),
        hour: 8,
        minute: 0,
      );
      expect(past.nextTriggerAt(now), isNull);
    });

    test('一次性闹钟未设日期时返回 null', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final alarm = Alarm(
        id: 'a3',
        label: '',
        repeatType: RepeatType.once,
        hour: 9,
        minute: 30,
      );
      expect(alarm.nextTriggerAt(now), isNull);
    });

    test('每天闹钟：今天已过则返回明天，未到则返回今天', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final alarm = Alarm(
        id: 'a4',
        label: '',
        repeatType: RepeatType.daily,
        hour: 7,
        minute: 0,
      );
      // 今天 7:00 已过 → 明天 7:00
      expect(alarm.nextTriggerAt(now), DateTime(2026, 10, 7, 7, 0));

      // 今天 18:00 未到 → 今天 18:00
      final evening = Alarm(
        id: 'a5',
        label: '',
        repeatType: RepeatType.daily,
        hour: 18,
        minute: 0,
      );
      expect(evening.nextTriggerAt(now), DateTime(2026, 10, 6, 18, 0));
    });

    test('每周闹钟：从今天起 7 天内找下一个匹配的星期', () {
      // 2026-10-06 是周二（weekday = 2）
      final now = DateTime(2026, 10, 6, 12, 0);
      final alarm = Alarm(
        id: 'a6',
        label: '',
        repeatType: RepeatType.weekly,
        hour: 8,
        minute: 30,
        weekdays: const [1, 5], // 周一、周五
      );
      // 下一个匹配是周五 10-09
      expect(alarm.nextTriggerAt(now), DateTime(2026, 10, 9, 8, 30));
    });

    test('每周闹钟：今天的时刻尚未到时优先今天', () {
      final now = DateTime(2026, 10, 6, 7, 0);
      final alarm = Alarm(
        id: 'a7',
        label: '',
        repeatType: RepeatType.weekly,
        hour: 9,
        minute: 0,
        weekdays: const [2], // 周二（今天）
      );
      expect(alarm.nextTriggerAt(now), DateTime(2026, 10, 6, 9, 0));
    });

    test('每周闹钟未选星期时返回 null', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final alarm = Alarm(
        id: 'a8',
        label: '',
        repeatType: RepeatType.weekly,
        hour: 9,
        minute: 0,
        weekdays: const [],
      );
      expect(alarm.nextTriggerAt(now), isNull);
    });
  });

  group('Alarm JSON 序列化', () {
    test('序列化后可完整还原', () {
      final alarm = Alarm(
        id: 'test-id-1',
        label: '发布会',
        repeatType: RepeatType.once,
        onceDate: DateTime(2026, 11, 6),
        hour: 9,
        minute: 30,
        ringtoneId: 'builtin:chime',
        vibrate: false,
        volumeRamp: true,
        snoozeMinutes: 10,
        snoozeCount: 2,
        colorValue: 0xFF34C77B,
      );
      final restored = Alarm.fromJson(alarm.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, alarm.id);
      expect(restored.label, alarm.label);
      expect(restored.repeatType, alarm.repeatType);
      expect(restored.onceDate, alarm.onceDate);
      expect(restored.hour, alarm.hour);
      expect(restored.minute, alarm.minute);
      expect(restored.ringtoneId, alarm.ringtoneId);
      expect(restored.vibrate, alarm.vibrate);
      expect(restored.volumeRamp, alarm.volumeRamp);
      expect(restored.snoozeMinutes, alarm.snoozeMinutes);
      expect(restored.snoozeCount, alarm.snoozeCount);
      expect(restored.colorValue, alarm.colorValue);
    });

    test('非法字段被拒绝或取默认值（防御脏数据）', () {
      expect(Alarm.fromJson({'id': '', 'repeatType': 0, 'hour': 1, 'minute': 0}), isNull);
      expect(Alarm.fromJson({'id': 'x', 'repeatType': 9, 'hour': 1, 'minute': 0}), isNull);
      expect(Alarm.fromJson({'id': 'x', 'repeatType': 0, 'hour': 25, 'minute': 0}), isNull);
      expect(Alarm.fromJson({'id': 'x', 'repeatType': 0, 'hour': 1, 'minute': -1}), isNull);
      // 合法但缺省字段 → 默认值
      final alarm = Alarm.fromJson({'id': 'x', 'repeatType': 0, 'hour': 7, 'minute': 30});
      expect(alarm, isNotNull);
      expect(alarm!.ringtoneId, 'default');
      expect(alarm.enabled, isTrue);
      expect(alarm.vibrate, isTrue);
    });
  });

  group('农历闹钟规则', () {
    test('每年农历重复：触发日为该农历月日对应的公历日期', () {
      final alarm = Alarm(
        id: 'lunar-yearly',
        label: '生日',
        repeatType: RepeatType.yearly,
        calendar: CalendarType.lunar,
        lunarMonth: 1,
        lunarDay: 1,
        hour: 8,
        minute: 0,
      );
      final t = alarm.nextTriggerAt(DateTime(2026, 10, 6, 12, 0));
      // 2026 春节已过（2/17），下一次为 2027 年正月初一 = 2027-02-06
      expect(t, DateTime(2027, 2, 6, 8, 0));
    });

    test('每月农历重复：返回未来某个月的农历日', () {
      final alarm = Alarm(
        id: 'lunar-monthly',
        label: '十五',
        repeatType: RepeatType.monthly,
        calendar: CalendarType.lunar,
        lunarDay: 15,
        hour: 7,
        minute: 30,
      );
      final t = alarm.nextTriggerAt(DateTime(2026, 10, 6, 12, 0));
      expect(t, isNotNull);
      expect(t!.isAfter(DateTime(2026, 10, 6, 12, 0)), isTrue);
    });

    test('每年公历重复：2 月 29 日遇平年取 28 日', () {
      final alarm = Alarm(
        id: 'solar-yearly',
        label: '',
        repeatType: RepeatType.yearly,
        calendar: CalendarType.solar,
        solarMonth: 2,
        solarDay: 29,
        hour: 9,
        minute: 0,
      );
      final t = alarm.nextTriggerAt(DateTime(2026, 10, 6, 12, 0));
      expect(t, DateTime(2027, 2, 28, 9, 0));
    });

    test('futureTriggers：返回未来若干次触发且时间递增', () {
      final alarm = Alarm(
        id: 'ft',
        label: '',
        repeatType: RepeatType.monthly,
        calendar: CalendarType.solar,
        solarDay: 1,
        hour: 8,
        minute: 0,
      );
      final triggers = alarm.futureTriggers(count: 3);
      expect(triggers.length, 3);
      expect(triggers[0] < triggers[1] && triggers[1] < triggers[2], isTrue);
    });

    test('JSON 往返保留农历与日历字段', () {
      final alarm = Alarm(
        id: 'lunar-json',
        label: '端午',
        repeatType: RepeatType.yearly,
        calendar: CalendarType.lunar,
        lunarMonth: 5,
        lunarDay: 5,
        isLeapMonth: false,
        hour: 8,
        minute: 0,
      );
      final restored = Alarm.fromJson(alarm.toJson());
      expect(restored, isNotNull);
      expect(restored!.calendar, CalendarType.lunar);
      expect(restored.lunarMonth, 5);
      expect(restored.lunarDay, 5);
      expect(restored.isLeapMonth, isFalse);
    });

    test('缺省字段默认公历（防御脏数据）', () {
      final restored = Alarm.fromJson({
        'id': 'legacy',
        'repeatType': 0,
        'hour': 7,
        'minute': 30,
      });
      expect(restored, isNotNull);
      expect(restored!.calendar, CalendarType.solar);
    });
  });
}
