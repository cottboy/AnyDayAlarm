import 'package:lunar/lunar.dart';

/// 农历换算封装：闹钟业务所需的全部农历规则收敛在这里。
///
/// 边界规则（按产品决策）：
/// * 农历"三十"遇小月（只有廿九）→ 提前一天，取月末日；
/// * 每年重复遇闰月年份 → 默认永远取正月份（忽略闰月）；
///   用户显式选择闰月（isLeapMonth=true）时只在闰月年份触发。
class LunarHelper {
  LunarHelper._();

  /// 农历某年某月某日 → 公历日期（零点）。
  /// 超出日界/该年无此闰月/日期非法时返回 null。
  static DateTime? lunarToSolar(
    int lunarYear,
    int lunarMonth,
    bool isLeapMonth,
    int lunarDay,
  ) {
    if (lunarYear < 1 || lunarYear > 9999) return null;
    if (lunarMonth < 1 || lunarMonth > 12) return null;
    if (lunarDay < 1 || lunarDay > 30) return null;
    final ym = isLeapMonth ? -lunarMonth : lunarMonth;
    final month = LunarMonth.fromYm(lunarYear, ym);
    if (month == null) return null;
    // "三十"遇小月：提前一天取月末日
    final day = lunarDay > month.getDayCount() ? month.getDayCount() : lunarDay;
    final solar = Lunar.fromYmd(lunarYear, ym, day).getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  }

  /// 下一次"每年农历月日"触发时刻（从 [now] 起未来寻找）。
  /// 非闰月最多看 4 个农历年；显式闰月因间隔可达十余年，最多看 30 个农历年。
  static DateTime? nextLunarYearly(
    int lunarMonth,
    bool isLeapMonth,
    int lunarDay,
    DateTime now,
    int hour,
    int minute,
  ) {
    if (lunarMonth < 1 || lunarMonth > 12) return null;
    if (lunarDay < 1 || lunarDay > 30) return null;
    final startLunar = Lunar.fromDate(now);
    final startYear = startLunar.getYear();
    final span = isLeapMonth ? 30 : 4;
    for (var y = startYear; y <= startYear + span; y++) {
      final solar = lunarToSolar(y, lunarMonth, isLeapMonth, lunarDay);
      if (solar == null) continue;
      final trigger = DateTime(solar.year, solar.month, solar.day, hour, minute);
      if (trigger.isAfter(now)) return trigger;
    }
    return null;
  }

  /// 下一次"每月农历日"触发时刻。逐农历月推进（自动跨闰月/跨年），最多看 16 个月。
  static DateTime? nextLunarMonthly(
    int lunarDay,
    DateTime now,
    int hour,
    int minute,
  ) {
    if (lunarDay < 1 || lunarDay > 30) return null;
    var current = LunarMonth.fromYm(
      Lunar.fromDate(now).getYear(),
      Lunar.fromDate(now).getMonth(),
    );
    for (var i = 0; i < 16 && current != null; i++) {
      final solar = lunarToSolar(current.getYear(), current.getMonth().abs(), current.getMonth() < 0, lunarDay);
      if (solar != null) {
        final trigger = DateTime(solar.year, solar.month, solar.day, hour, minute);
        if (trigger.isAfter(now)) return trigger;
      }
      current = current.next(1);
    }
    return null;
  }

  /// 下一次"每年公历月日"触发时刻。2 月 29 日遇平年取 2 月 28 日（月末日规则）。
  static DateTime? nextSolarYearly(
    int month,
    int day,
    DateTime now,
    int hour,
    int minute,
  ) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    for (var y = now.year; y <= now.year + 3; y++) {
      final trigger = _solarDateClamped(y, month, day, hour, minute);
      if (trigger != null && trigger.isAfter(now)) return trigger;
    }
    return null;
  }

  /// 下一次"每月公历日"触发时刻。31 遇小月、30/31 遇 2 月均取当月最后一天。
  static DateTime? nextSolarMonthly(int day, DateTime now, int hour, int minute) {
    if (day < 1 || day > 31) return null;
    for (var i = 0; i < 3; i++) {
      final month = DateTime(now.year, now.month + i);
      final trigger = _solarDateClamped(month.year, month.month, day, hour, minute);
      if (trigger != null && trigger.isAfter(now)) return trigger;
    }
    return null;
  }

  /// 公历月日 → 具体日期；日超出当月天数时取当月最后一天。
  static DateTime? _solarDateClamped(int year, int month, int day, int hour, int minute) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day, hour, minute);
  }

  /// 公历日期 → 农历显示描述，如"农历六月初八"、"农历闰六月十五"。
  static String lunarLabel(DateTime date) {
    final lunar = Lunar.fromDate(date);
    return '农历${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  }

  /// 农历年在选择器中的显示文案，如"2026 丙午"。
  static String lunarYearLabel(int lunarYear) {
    return '$lunarYear ${LunarYear.fromYear(lunarYear).getGanZhi()}';
  }

  /// 农历月名：1-12 → 正月~腊月；isLeap 时加"闰"。
  static String lunarMonthLabel(int month, bool isLeap) {
    final name = LunarUtil.MONTH[month];
    return '${isLeap ? '闰' : ''}$name月';
  }

  /// 农历日名：1-30 → 初一~三十。
  static String lunarDayLabel(int day) => LunarUtil.DAY[day];
}
