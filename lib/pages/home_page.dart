import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/alarm_repository.dart';
import '../l10n/app_localizations.dart';
import '../lunar/lunar_helper.dart';
import '../models/alarm.dart';
import '../services/alarm_platform.dart';
import 'edit_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository});

  final AlarmRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _exactOk = true;
  bool _notifyOk = true;
  bool _batteryOk = true;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final results = await Future.wait([
      AlarmPlatform.canScheduleExactAlarms(),
      AlarmPlatform.areNotificationsEnabled(),
      AlarmPlatform.isIgnoringBatteryOptimizations(),
    ]);
    if (!mounted) return;
    setState(() {
      _exactOk = results[0];
      _notifyOk = results[1];
      _batteryOk = results[2];
    });
  }

  /// 按"下一次触发时间"排序：启用的在前，未启用的按一天内时间排。
  List<Alarm> get _sorted {
    final now = DateTime.now();
    final list = [...widget.repository.alarms];
    list.sort((a, b) {
      final ta = a.nextTriggerAt(now);
      final tb = b.nextTriggerAt(now);
      if (ta != null && tb != null) return ta.compareTo(tb);
      if (ta != null) return -1;
      if (tb != null) return 1;
      final ma = a.hour * 60 + a.minute;
      final mb = b.hour * 60 + b.minute;
      return ma.compareTo(mb);
    });
    return list;
  }

  Future<void> _openEditor([Alarm? alarm]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditPage(repository: widget.repository, alarm: alarm),
      ),
    );
    setState(() {}); // 列表可能已变化
    _refreshPermissions();
  }

  Future<void> _toggle(Alarm alarm, bool enabled) async {
    // 一次性闹钟若已过期，开启时直接进编辑页修正日期
    if (enabled && alarm.nextTriggerAt(DateTime.now()) == null) {
      if (alarm.repeatType == RepeatType.once) {
        await _openEditor(alarm);
        return;
      }
    }
    alarm.enabled = enabled;
    await widget.repository.save(alarm);
    await AlarmPlatform.syncAndScheduleAll(widget.repository.alarms);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final alarms = _sorted;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.alarm_add_outlined),
      ),
      body: alarms.isEmpty
          ? _EmptyView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              children: [
                if (!_exactOk) _PermissionCard(
                  icon: Icons.alarm_off_outlined,
                  title: l10n.homePermissionBannerTitle,
                  body: l10n.homePermissionBannerBody,
                  actionLabel: l10n.homePermissionBannerAction,
                  onAction: () async {
                    await AlarmPlatform.openExactAlarmSettings();
                    _refreshPermissions();
                  },
                )
                else if (!_notifyOk) _PermissionCard(
                  icon: Icons.notifications_off_outlined,
                  title: l10n.homePermissionBannerTitle,
                  body: l10n.homePermissionBannerBody,
                  actionLabel: l10n.homePermissionBannerAction,
                  onAction: () async {
                    await AlarmPlatform.openNotificationSettings();
                    _refreshPermissions();
                  },
                )
                else if (!_batteryOk) _PermissionCard(
                  icon: Icons.battery_saver_outlined,
                  title: l10n.homeBatteryBannerTitle,
                  body: l10n.homeBatteryBannerBody,
                  actionLabel: l10n.homePermissionBannerAction,
                  onAction: () async {
                    await AlarmPlatform.requestIgnoreBatteryOptimizations();
                    _refreshPermissions();
                  },
                ),
                ...alarms.map((a) => _AlarmCard(
                      alarm: a,
                      onToggle: (v) => _toggle(a, v),
                      onTap: () => _openEditor(a),
                    )),
              ],
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.alarm_on_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.homeEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.alarm, required this.onToggle, required this.onTap});

  final Alarm alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  String _repeatText(AppLocalizations l10n, BuildContext context) {
    switch (alarm.repeatType) {
      case RepeatType.once:
        final d = alarm.onceDate;
        if (d == null) return l10n.repeatTypeOnce;
        if (alarm.calendar == CalendarType.lunar) {
          return l10n.lunarDateLabel(LunarHelper.lunarLabel(d).replaceFirst('农历', ''));
        }
        final locale = Localizations.localeOf(context).toString();
        return DateFormat.yMMMd(locale).format(d);
      case RepeatType.daily:
        return l10n.repeatEveryDay;
      case RepeatType.weekly:
        final names = {
          1: l10n.weekdayMon,
          2: l10n.weekdayTue,
          3: l10n.weekdayWed,
          4: l10n.weekdayThu,
          5: l10n.weekdayFri,
          6: l10n.weekdaySat,
          7: l10n.weekdaySun,
        };
        if (alarm.weekdays.length == 7) return l10n.repeatEveryDay;
        final sorted = [...alarm.weekdays]..sort();
        return l10n.repeatWeekdays(sorted.map((w) => names[w] ?? '').join('、'));
      case RepeatType.yearly:
        if (alarm.calendar == CalendarType.lunar) {
          final m = alarm.lunarMonth;
          final d = alarm.lunarDay;
          if (m == null || d == null) return l10n.repeatTypeYearly;
          final leap = alarm.isLeapMonth ? '闰' : '';
          return l10n.repeatYearlyLunar(
            '$leap${LunarHelper.lunarMonthLabel(m, false).replaceAll('月', '')}月${LunarHelper.lunarDayLabel(d)}',
          );
        }
        final m = alarm.solarMonth;
        final d = alarm.solarDay;
        if (m == null || d == null) return l10n.repeatTypeYearly;
        return l10n.repeatYearlySolar(m, d);
      case RepeatType.monthly:
        if (alarm.calendar == CalendarType.lunar) {
          final d = alarm.lunarDay;
          if (d == null) return l10n.repeatTypeMonthly;
          return l10n.repeatMonthlyLunar(LunarHelper.lunarDayLabel(d));
        }
        final d = alarm.solarDay;
        if (d == null) return l10n.repeatTypeMonthly;
        return l10n.repeatMonthlySolar(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(alarm.colorValue);
    final active = alarm.enabled;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? accent : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: active
                                ? scheme.onSurface
                                : scheme.outline,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (alarm.label.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              alarm.label,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: active ? accent : scheme.outline,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            _repeatText(l10n, context),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.outline,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(value: active, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}
