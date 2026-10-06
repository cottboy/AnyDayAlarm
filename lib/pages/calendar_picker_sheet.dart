import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';

import '../l10n/app_localizations.dart';
import '../lunar/lunar_helper.dart';

/// 农历选择结果
class LunarPick {
  const LunarPick({this.year, required this.month, this.isLeap = false, required this.day});

  /// 农历年（仅一次性选择时需要）
  final int? year;
  final int month;
  final bool isLeap;
  final int day;
}

/// 农历日期轮子选择弹层。
///
/// [forOnce] 为 true 时包含年份轮子（选某个具体农历日）；
/// 否则为"每年/每月"规则选择（只选月日，闰月开关仅在 [allowLeap] 时显示）。
class LunarDateSheet extends StatefulWidget {
  const LunarDateSheet({super.key, required this.forOnce, this.allowLeap = true, this.initial});

  final bool forOnce;
  final bool allowLeap;
  final LunarPick? initial;

  @override
  State<LunarDateSheet> createState() => _LunarDateSheetState();
}

class _LunarDateSheetState extends State<LunarDateSheet> {
  late int? _year;
  late int _month;
  late bool _leap;
  late int _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentLunarYear = Lunar.fromDate(now).getYear();
    final init = widget.initial;
    _year = widget.forOnce ? (init?.year ?? currentLunarYear) : null;
    _month = init?.month ?? 1;
    _leap = init?.isLeap ?? false;
    _day = init?.day ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final preview = _year != null
        ? LunarHelper.lunarToSolar(_year!, _month, _leap, _day)
        : null;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.calendarLunar, style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () {
                    if (widget.forOnce && preview == null) return; // 换算失败禁止确认
                    Navigator.of(context).pop(LunarPick(
                      year: _year,
                      month: _month,
                      isLeap: _leap,
                      day: _day,
                    ));
                  },
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          ),
          if (widget.forOnce) ...[
            SwitchListTile(
              title: Text(l10n.calendarLunar),
              subtitle: Text(l10n.lunarLeapMonthHint(
                LunarHelper.lunarMonthLabel(_month, false).replaceAll('月', ''),
              )),
              // 开关语义即"选择闰月"
              value: _leap,
              onChanged: (v) => setState(() => _leap = v),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ] else if (widget.allowLeap) ...[
            SwitchListTile(
              title: Text(l10n.lunarLeapMonthSwitch),
              subtitle: Text(l10n.lunarLeapMonthHint(
                LunarHelper.lunarMonthLabel(_month, false).replaceAll('月', ''),
              )),
              value: _leap,
              onChanged: (v) => setState(() => _leap = v),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ],
          SizedBox(
            height: 180,
            child: Row(
              children: [
                if (widget.forOnce)
                  _Wheel(
                    width: 140,
                    itemCount: 61,
                    initialIndex: _year! - Lunar.fromDate(DateTime.now()).getYear(),
                    label: (offset) => LunarHelper.lunarYearLabel(
                        Lunar.fromDate(DateTime.now()).getYear() + offset),
                    onChanged: (i) => setState(() {
                      _year = Lunar.fromDate(DateTime.now()).getYear() + i;
                    }),
                  ),
                _Wheel(
                  width: 110,
                  itemCount: 12,
                  initialIndex: _month - 1,
                  label: (i) => LunarHelper.lunarMonthLabel(i + 1, false),
                  onChanged: (i) => setState(() => _month = i + 1),
                ),
                _Wheel(
                  width: 110,
                  itemCount: 30,
                  initialIndex: _day - 1,
                  label: (i) => LunarHelper.lunarDayLabel(i + 1),
                  onChanged: (i) => setState(() => _day = i + 1),
                ),
              ],
            ),
          ),
          if (widget.forOnce)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Text(
                preview != null
                    ? l10n.lunarDatePreview('${preview.year}/${preview.month}/${preview.day}')
                    : l10n.lunarNoSolarDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: preview == null ? scheme.error : scheme.outline,
                    ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 公历"每年月日 / 每月日"轮子弹层。返回 (month?, day)。
class SolarRuleSheet extends StatefulWidget {
  const SolarRuleSheet({super.key, required this.forYearly, this.initialMonth, this.initialDay});

  final bool forYearly;
  final int? initialMonth;
  final int? initialDay;

  @override
  State<SolarRuleSheet> createState() => _SolarRuleSheetState();
}

class _SolarRuleSheetState extends State<SolarRuleSheet> {
  late int? _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    _month = widget.forYearly ? (widget.initialMonth ?? 1) : null;
    _day = widget.initialDay ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.calendarSolar, style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop((_month, _day)),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                if (widget.forYearly)
                  _Wheel(
                    width: 140,
                    itemCount: 12,
                    initialIndex: _month! - 1,
                    label: (i) => '${i + 1} ${l10n.lunarPickerMonth}',
                    onChanged: (i) => setState(() => _month = i + 1),
                  ),
                _Wheel(
                  width: 140,
                  itemCount: 31,
                  initialIndex: _day - 1,
                  label: (i) => '${i + 1} ${l10n.lunarPickerDay}',
                  onChanged: (i) => setState(() => _day = i + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.width,
    required this.itemCount,
    required this.initialIndex,
    required this.label,
    required this.onChanged,
  });

  final double width;
  final int itemCount;
  final int initialIndex;
  final String Function(int index) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: initialIndex.clamp(0, itemCount - 1)),
        itemExtent: 40,
        magnification: 1.1,
        squeeze: 1.1,
        useMagnifier: true,
        onSelectedItemChanged: onChanged,
        children: [
          for (var i = 0; i < itemCount; i++)
            Center(child: Text(label(i), style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
