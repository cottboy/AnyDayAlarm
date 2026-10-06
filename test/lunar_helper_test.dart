import 'package:flutter_test/flutter_test.dart';
import 'package:lunar/lunar.dart';

import 'package:any_day_alarm/lunar/lunar_helper.dart';

void main() {
  group('农历↔公历对照（历书事实验收）', () {
    test('春节日期：2024=2/10，2025=1/29，2026=2/17', () {
      expect(LunarHelper.lunarToSolar(2024, 1, false, 1), DateTime(2024, 2, 10));
      expect(LunarHelper.lunarToSolar(2025, 1, false, 1), DateTime(2025, 1, 29));
      expect(LunarHelper.lunarToSolar(2026, 1, false, 1), DateTime(2026, 2, 17));
    });

    test('闰月：2023 闰二月初一 = 2023-03-22', () {
      expect(LunarHelper.lunarToSolar(2023, 2, true, 1), DateTime(2023, 3, 22));
      // 非闰二月初一是另一天
      expect(LunarHelper.lunarToSolar(2023, 2, false, 1), DateTime(2023, 2, 20));
    });

    test('"三十"遇小月提前一天：2022 腊月只有廿九，除夕取廿九', () {
      // 2023 年春节是 1/22，其除夕（腊月末）= 1/21，且 2022 腊月是小月
      final solar = LunarHelper.lunarToSolar(2022, 12, false, 30);
      expect(solar, DateTime(2023, 1, 21));
    });

    test('"三十"为大月时正常触发：2021 腊月三十 = 2022-01-31', () {
      expect(LunarHelper.lunarToSolar(2021, 12, false, 30), DateTime(2022, 1, 31));
    });

    test('无效输入返回 null（防御）', () {
      expect(LunarHelper.lunarToSolar(2026, 13, false, 1), isNull);
      expect(LunarHelper.lunarToSolar(2026, 0, false, 1), isNull);
      expect(LunarHelper.lunarToSolar(2026, 6, false, 0), isNull);
      expect(LunarHelper.lunarToSolar(2026, 6, false, 31), isNull);
      expect(LunarHelper.lunarToSolar(9999, 6, false, 1), isNotNull); // 年界内有效
      expect(LunarHelper.lunarToSolar(10000, 6, false, 1), isNull);
      expect(LunarHelper.lunarToSolar(0, 6, false, 1), isNull);
    });
  });

  group('每年农历重复', () {
    final now = DateTime(2026, 10, 6, 12, 0);

    test('下一次触发是未来的农历六月初八', () {
      final t = LunarHelper.nextLunarYearly(6, false, 8, now, 9, 30);
      expect(t, isNotNull);
      expect(t!.isAfter(now), isTrue);
      final lunar = Lunar.fromDate(t);
      expect(lunar.getMonth(), 6);
      expect(lunar.getDay(), 8);
    });

    test('今年已过则取明年，触发时刻包含时分', () {
      // 2026 农历六月初八在 7 月，10 月时已过 → 应为 2027
      final t = LunarHelper.nextLunarYearly(6, false, 8, now, 9, 30);
      expect(t!.year, 2027);
      expect(t.hour, 9);
      expect(t.minute, 30);
    });

    test('忽略闰月：正月初一每年都触发（含无闰月年份）', () {
      final t = LunarHelper.nextLunarYearly(1, false, 1, now, 0, 0);
      final lunar = Lunar.fromDate(t!);
      expect(lunar.getMonth(), 1);
      expect(lunar.getDay(), 1);
    });

    test('显式闰月：只在闰月年份触发', () {
      final t = LunarHelper.nextLunarYearly(6, true, 1, now, 8, 0);
      expect(t, isNotNull);
      final lunar = Lunar.fromDate(t!);
      expect(lunar.getMonth(), -6); // 闰月为负数
      expect(lunar.getMonth() < 0, isTrue); // 必然落在闰六月
    });

    test('"三十"缺失年份自动提前一天，取该月最后一天', () {
      for (var i = 0; i < 3; i++) {
        final t = LunarHelper.nextLunarYearly(1, false, 30, now.add(Duration(days: 400 * i)), 8, 0);
        expect(t, isNotNull);
        final lunar = Lunar.fromDate(t!);
        // 该日要么是三十，要么是该农历月的最后一天（廿九）
        final monthDayCount =
            LunarMonth.fromYm(lunar.getYear(), lunar.getMonth())!.getDayCount();
        expect(lunar.getDay(), monthDayCount);
      }
    });
  });

  group('每月农历重复', () {
    final now = DateTime(2026, 10, 6, 12, 0);

    test('下一次触发是未来的农历初八', () {
      final t = LunarHelper.nextLunarMonthly(8, now, 7, 0);
      expect(t, isNotNull);
      final lunar = Lunar.fromDate(t!);
      expect(lunar.getDay(), 8);
      expect(t.isAfter(now), isTrue);
    });

    test('初一十五跨闰月推进不丢月份', () {
      final t = LunarHelper.nextLunarMonthly(15, now, 8, 0);
      final lunar = Lunar.fromDate(t!);
      expect(lunar.getDay(), 15);
      // 2026-10-06 之后一个月内必有下一个十五（农历每月必有十五）
      expect(t.isBefore(now.add(const Duration(days: 40))), isTrue);
    });
  });

  group('公历每年/每月', () {
    test('每年 2 月 29 日遇平年取 2 月 28 日', () {
      final now = DateTime(2026, 10, 6, 12, 0); // 2027、2028 为平/闰年
      final t = LunarHelper.nextSolarYearly(2, 29, now, 8, 0);
      expect(t!.year, 2027); // 2028 才闰，但 2027 已提前一天过
      expect(t.month, 2);
      expect(t.day, 28);
    });

    test('每月 31 日遇小月取月末', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final t = LunarHelper.nextSolarMonthly(31, now, 8, 0);
      // 10 月有 31 天 → 10/31
      expect(t, DateTime(2026, 10, 31, 8, 0));
      final t2 = LunarHelper.nextSolarMonthly(31, DateTime(2026, 11, 1, 0, 0), 8, 0);
      // 11 月 30 天 → 11/30
      expect(t2, DateTime(2026, 11, 30, 8, 0));
    });
  });

  group('农历显示文案', () {
    test('lunarLabel 输出', () {
      expect(LunarHelper.lunarLabel(DateTime(2026, 2, 17)), '农历正月初一');
      expect(LunarHelper.lunarLabel(DateTime(2023, 3, 22)), '农历闰二月初一');
    });
  });
}
