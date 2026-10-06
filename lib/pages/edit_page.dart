import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';

import '../data/alarm_repository.dart';
import '../l10n/app_localizations.dart';
import '../lunar/lunar_helper.dart';
import '../models/alarm.dart';
import '../services/alarm_platform.dart';
import 'calendar_picker_sheet.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.repository, this.alarm});

  final AlarmRepository repository;
  final Alarm? alarm;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late Alarm _draft;
  late TextEditingController _labelController;

  bool get _isNew => widget.alarm == null;

  @override
  void initState() {
    super.initState();
    final src = widget.alarm;
    if (src != null) {
      _draft = src.copyWith();
    } else {
      final now = DateTime.now();
      var hour = now.hour + 1;
      var minute = 0;
      if (hour > 23) hour = hour - 24;
      _draft = Alarm(
        id: Alarm.newId(),
        label: '',
        repeatType: RepeatType.once,
        onceDate: DateTime(now.year, now.month, now.day),
        hour: hour,
        minute: minute,
      );
    }
    _labelController = TextEditingController(text: _draft.label);
  }

  @override
  void dispose() {
    _labelController.dispose();
    AlarmPlatform.stopRingtonePreview();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.hour, minute: _draft.minute),
      builder: (context, child) => MediaQuery(
        // 统一 24 小时制，避免上午/下午选择与 24h 显示不一致
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _draft.hour = picked.hour;
        _draft.minute = picked.minute;
      });
    }
  }

  Future<void> _pickOnceSolar() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.onceDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _draft.onceDate = picked);
    }
  }

  /// 农历一次性日期：轮子选择后立即换算为公历存入 onceDate。
  Future<void> _pickOnceLunar() async {
    final init = _draft.onceDate == null
        ? null
        : () {
            final lunar = Lunar.fromDate(_draft.onceDate!);
            return LunarPick(
              year: lunar.getYear(),
              month: lunar.getMonth().abs(),
              isLeap: lunar.getMonth() < 0,
              day: lunar.getDay(),
            );
          }();
    final pick = await showModalBottomSheet<LunarPick>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => LunarDateSheet(forOnce: true, initial: init),
    );
    if (pick == null || pick.year == null) return;
    final solar = LunarHelper.lunarToSolar(pick.year!, pick.month, pick.isLeap, pick.day);
    if (!mounted) return;
    if (solar == null) {
      _toast(AppLocalizations.of(context)!.lunarNoSolarDate);
      return;
    }
    setState(() => _draft.onceDate = solar);
  }

  Future<void> _pickYearly() async {
    if (_draft.calendar == CalendarType.lunar) {
      final pick = await showModalBottomSheet<LunarPick>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => LunarDateSheet(
          forOnce: false,
          allowLeap: true,
          initial: LunarPick(month: _draft.lunarMonth ?? 1, isLeap: _draft.isLeapMonth, day: _draft.lunarDay ?? 1),
        ),
      );
      if (pick == null) return;
      setState(() {
        _draft.lunarMonth = pick.month;
        _draft.isLeapMonth = pick.isLeap;
        _draft.lunarDay = pick.day;
      });
    } else {
      final pick = await showModalBottomSheet<(int?, int)>(
        context: context,
        showDragHandle: true,
        builder: (_) => SolarRuleSheet(
          forYearly: true,
          initialMonth: _draft.solarMonth,
          initialDay: _draft.solarDay,
        ),
      );
      if (pick == null) return;
      setState(() {
        _draft.solarMonth = pick.$1;
        _draft.solarDay = pick.$2;
      });
    }
  }

  Future<void> _pickMonthly() async {
    if (_draft.calendar == CalendarType.lunar) {
      final pick = await showModalBottomSheet<LunarPick>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => LunarDateSheet(
          forOnce: false,
          allowLeap: false,
          initial: LunarPick(month: _draft.lunarMonth ?? 1, day: _draft.lunarDay ?? 1),
        ),
      );
      if (pick == null) return;
      setState(() => _draft.lunarDay = pick.day);
    } else {
      final pick = await showModalBottomSheet<(int?, int)>(
        context: context,
        showDragHandle: true,
        builder: (_) => SolarRuleSheet(forYearly: false, initialDay: _draft.solarDay),
      );
      if (pick == null) return;
      setState(() => _draft.solarDay = pick.$2);
    }
  }

  /// 切换重复类型时补齐对应规则的默认值，保证任何组合都有合法数据。
  void _onRepeatTypeChanged(RepeatType type) {
    setState(() {
      _draft.repeatType = type;
      _ensureRuleDefaults();
    });
  }

  void _ensureRuleDefaults() {
    final now = DateTime.now();
    final lunarNow = Lunar.fromDate(now);
    switch (_draft.repeatType) {
      case RepeatType.yearly:
        _draft.solarMonth ??= now.month;
        _draft.solarDay ??= now.day;
        _draft.lunarMonth ??= lunarNow.getMonth().abs();
        _draft.lunarDay ??= lunarNow.getDay();
      case RepeatType.monthly:
        _draft.solarDay ??= now.day;
        _draft.lunarDay ??= lunarNow.getDay();
      default:
        break;
    }
  }

  bool get _repeatUsesCalendar =>
      _draft.repeatType == RepeatType.once ||
      _draft.repeatType == RepeatType.yearly ||
      _draft.repeatType == RepeatType.monthly;

  String _repeatTypeLabel(AppLocalizations l10n, RepeatType type) {
    return switch (type) {
      RepeatType.once => l10n.repeatTypeOnce,
      RepeatType.daily => l10n.repeatTypeDaily,
      RepeatType.weekly => l10n.repeatTypeWeekly,
      RepeatType.yearly => l10n.repeatTypeYearly,
      RepeatType.monthly => l10n.repeatTypeMonthly,
    };
  }

  String _onceDateSubtitle(AppLocalizations l10n) {
    final d = _draft.onceDate;
    if (d == null) return l10n.editRingDate;
    if (_draft.calendar == CalendarType.lunar) {
      return '${LunarHelper.lunarLabel(d)} · ${d.year}/${d.month}/${d.day}';
    }
    return '${d.year}/${d.month}/${d.day}';
  }

  String _yearlySubtitle(AppLocalizations l10n) {
    if (_draft.calendar == CalendarType.lunar) {
      final m = _draft.lunarMonth;
      final d = _draft.lunarDay;
      if (m == null || d == null) return l10n.repeatTypeYearly;
      return l10n.repeatYearlyLunar(
        '${_draft.isLeapMonth ? '闰' : ''}${LunarHelper.lunarMonthLabel(m, false).replaceAll('月', '')}月${LunarHelper.lunarDayLabel(d)}',
      );
    }
    final m = _draft.solarMonth;
    final d = _draft.solarDay;
    if (m == null || d == null) return l10n.repeatTypeYearly;
    return l10n.repeatYearlySolar(m, d);
  }

  String _monthlySubtitle(AppLocalizations l10n) {
    if (_draft.calendar == CalendarType.lunar) {
      final d = _draft.lunarDay;
      if (d == null) return l10n.repeatTypeMonthly;
      return l10n.repeatMonthlyLunar(LunarHelper.lunarDayLabel(d));
    }
    final d = _draft.solarDay;
    if (d == null) return l10n.repeatTypeMonthly;
    return l10n.repeatMonthlySolar(d);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    _draft.label = _labelController.text.trim();

    if (_draft.repeatType == RepeatType.once) {
      if (_draft.onceDate == null) {
        _toast(l10n.errorDateRequired);
        return;
      }
      final trigger = DateTime(
        _draft.onceDate!.year,
        _draft.onceDate!.month,
        _draft.onceDate!.day,
        _draft.hour,
        _draft.minute,
      );
      if (!trigger.isAfter(DateTime.now())) {
        _toast(l10n.errorDatePast);
        return;
      }
    }
    if (_draft.repeatType == RepeatType.weekly && _draft.weekdays.isEmpty) {
      // 未选任何星期时默认勾选当天，避免出现永不触发的闹钟
      _draft.weekdays = [DateTime.now().weekday];
    }

    await widget.repository.save(_draft);
    await AlarmPlatform.syncAndScheduleAll(widget.repository.alarms);
    if (!mounted) return;
    _toast(l10n.toastSaved);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editDeleteConfirmTitle),
        content: Text(l10n.editDeleteConfirmBody(_draft.label.isEmpty ? l10n.ringAlarmLabel : _draft.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.editDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.remove(_draft.id);
    await AlarmPlatform.syncAndScheduleAll(widget.repository.alarms);
    if (!mounted) return;
    _toast(l10n.toastDeleted);
    Navigator.of(context).pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _showRingtoneSheet() async {
    AlarmPlatform.stopRingtonePreview();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RingtoneSheet(
        currentId: _draft.ringtoneId,
        currentCustomName: _customRingtoneName,
        onSelected: (id, name) {
          setState(() {
            _draft.ringtoneId = id;
            _customRingtoneName = name;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.editTitleNew : l10n.editTitleExisting),
        actions: [
          if (!_isNew)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: Text(l10n.editSave)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 时间
          Center(
            child: InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  '${_draft.hour.toString().padLeft(2, '0')}:${_draft.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 标签
          TextField(
            controller: _labelController,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: l10n.editLabelHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),

          // 重复
          Text(l10n.editSectionRepeat, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              // 枚举声明顺序即触发间隔从小到大
              for (final type in RepeatType.values)
                ChoiceChip(
                  label: Text(_repeatTypeLabel(l10n, type)),
                  selected: _draft.repeatType == type,
                  // 关闭选中勾号：勾号插入会使 chip 宽度突变，导致整行重新排版跳动
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  onSelected: (_) => _onRepeatTypeChanged(type),
                ),
            ],
          ),
          if (_repeatUsesCalendar) ...[
            const SizedBox(height: 12),
            SegmentedButton<CalendarType>(
              segments: [
                ButtonSegment(value: CalendarType.solar, label: Text(l10n.calendarSolar)),
                ButtonSegment(value: CalendarType.lunar, label: Text(l10n.calendarLunar)),
              ],
              selected: {_draft.calendar},
              onSelectionChanged: (selection) {
                setState(() => _draft.calendar = selection.first);
              },
            ),
          ],
          ...switch (_draft.repeatType) {
            RepeatType.once => [
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(l10n.editRingDate),
                    subtitle: Text(_onceDateSubtitle(l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _draft.calendar == CalendarType.lunar ? _pickOnceLunar : _pickOnceSolar,
                  ),
                ),
              ],
            RepeatType.daily => [const SizedBox(height: 4)],
            RepeatType.weekly => [
                const SizedBox(height: 12),
                _WeekdaySelector(
                  selected: _draft.weekdays,
                  onChanged: (days) => setState(() => _draft.weekdays = days),
                ),
              ],
            RepeatType.yearly => [
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(l10n.repeatTypeYearly),
                    subtitle: Text(_yearlySubtitle(l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickYearly,
                  ),
                ),
              ],
            RepeatType.monthly => [
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.date_range_outlined),
                    title: Text(l10n.repeatTypeMonthly),
                    subtitle: Text(_monthlySubtitle(l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickMonthly,
                  ),
                ),
              ],
          },
          const SizedBox(height: 16),

          // 铃声
          Text(l10n.editSectionRingtone, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(_ringtoneLabel(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showRingtoneSheet,
            ),
          ),
          const SizedBox(height: 16),

          // 响铃行为
          Text(l10n.editSectionBehavior, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.editVolumeRamp),
                  subtitle: Text(l10n.editVolumeRampSubtitle),
                  value: _draft.volumeRamp,
                  onChanged: (v) => setState(() => _draft.volumeRamp = v),
                ),
                SwitchListTile(
                  title: Text(l10n.editVibrate),
                  secondary: const Icon(Icons.vibration_outlined),
                  value: _draft.vibrate,
                  onChanged: (v) => setState(() => _draft.vibrate = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 贪睡
          Text(l10n.editSectionSnooze, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: Text(_draft.snoozeCount > 0 ? l10n.editSnoozeMinutes(_draft.snoozeMinutes, _draft.snoozeCount) : l10n.editSnoozeOff),
              secondary: const Icon(Icons.snooze_outlined),
              value: _draft.snoozeCount > 0,
              onChanged: (v) => setState(() {
                _draft.snoozeCount = v ? 3 : 0;
              }),
            ),
          ),
          if (_draft.snoozeCount > 0) ...[
            const SizedBox(height: 8),
            _SnoozeSlider(
              label: l10n.editSnoozeInterval,
              valueLabel: l10n.editSnoozeIntervalUnit(_draft.snoozeMinutes),
              value: _draft.snoozeMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => setState(() => _draft.snoozeMinutes = v.round()),
            ),
            _SnoozeSlider(
              label: l10n.editSnoozeCount,
              valueLabel: l10n.editSnoozeCountUnit(_draft.snoozeCount),
              value: _draft.snoozeCount.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _draft.snoozeCount = v.round()),
            ),
          ],
          const SizedBox(height: 16),

          // 标签颜色
          Text(l10n.editSectionColor, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final c in RingtoneCatalog.labelColors)
                GestureDetector(
                  onTap: () => setState(() => _draft.colorValue = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: _draft.colorValue == c
                          ? Border.all(color: scheme.onSurface, width: 2.5)
                          : null,
                    ),
                    child: _draft.colorValue == c
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _ringtoneLabel(AppLocalizations l10n) {
    final id = _draft.ringtoneId;
    if (id == 'default') return l10n.editRingtoneDefault;
    if (id.startsWith('builtin:')) {
      final key = id.substring('builtin:'.length);
      return switch (key) {
        'classic' => l10n.ringtoneClassic,
        'digital' => l10n.ringtoneDigital,
        'chime' => l10n.ringtoneChime,
        'rise' => l10n.ringtoneRise,
        _ => l10n.editRingtoneDefault,
      };
    }
    if (id.startsWith('file:')) {
      return _customRingtoneName ?? l10n.editRingtonePick;
    }
    return l10n.editRingtoneDefault;
  }

  /// 已挑选的本地铃声显示名（仅保存路径，名称展示用）。
  String? _customRingtoneName;
}

class _SnoozeSlider extends StatelessWidget {
  const _SnoozeSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final shortNames = [
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
      l10n.weekdaySunShort,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 7; i++)
          GestureDetector(
            onTap: () {
              final day = i + 1;
              final next = [...selected];
              if (next.contains(day)) {
                next.remove(day);
              } else {
                next.add(day);
              }
              onChanged(next);
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor:
                  selected.contains(i + 1) ? scheme.primary : scheme.surfaceContainerHighest,
              child: Text(
                shortNames[i],
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected.contains(i + 1)
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 铃声选择底部弹层：点选即试听，再点同一项停止。
class _RingtoneSheet extends StatefulWidget {
  const _RingtoneSheet({
    required this.currentId,
    required this.currentCustomName,
    required this.onSelected,
  });

  final String currentId;
  final String? currentCustomName;
  final void Function(String id, String? name) onSelected;

  @override
  State<_RingtoneSheet> createState() => _RingtoneSheetState();
}

class _RingtoneSheetState extends State<_RingtoneSheet> {
  late String _selected;
  String? _previewingId;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentId;
  }

  Future<void> _togglePreview(String id) async {
    if (_previewingId == id) {
      await AlarmPlatform.stopRingtonePreview();
      setState(() => _previewingId = null);
      return;
    }
    await AlarmPlatform.playRingtonePreview(id);
    setState(() => _previewingId = id);
  }

  Future<void> _pickLocalAudio() async {
    await AlarmPlatform.stopRingtonePreview();
    final res = await AlarmPlatform.pickRingtone();
    if (!mounted) return;
    setState(() => _previewingId = null);
    if (res == null) return;
    _selected = 'file:${res['path']}';
    widget.onSelected(_selected, res['name']);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget tile({
      required String id,
      required String title,
      IconData icon = Icons.music_note_outlined,
      VoidCallback? onTapOverride,
    }) {
      final isCurrent = _selected == id;
      final isPreviewing = _previewingId == id;
      return ListTile(
        leading: Icon(isPreviewing ? Icons.stop_circle_outlined : icon),
        title: Text(
          title,
          style: isCurrent
              ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)
              : null,
        ),
        trailing: isCurrent ? Icon(Icons.check_circle, color: scheme.primary) : null,
        onTap: onTapOverride ??
            () async {
              if (isCurrent && isPreviewing) {
                await _togglePreview(id);
                return;
              }
              widget.onSelected(id, null);
              setState(() => _selected = id);
              await _togglePreview(id);
            },
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.editSectionRingtone,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          tile(id: 'default', title: l10n.editRingtoneDefault, icon: Icons.graphic_eq_outlined),
          for (final r in RingtoneCatalog.builtin)
            tile(
              id: r.id,
              title: switch (r.fileKey) {
                'classic' => l10n.ringtoneClassic,
                'digital' => l10n.ringtoneDigital,
                'chime' => l10n.ringtoneChime,
                'rise' => l10n.ringtoneRise,
                _ => r.fileKey,
              },
            ),
          if (_selected.startsWith('file:'))
            tile(
              id: _selected,
              title: widget.currentCustomName ?? l10n.editRingtonePick,
              icon: Icons.audiotrack_outlined,
            ),
          tile(
            id: '__pick__',
            title: l10n.editRingtonePick,
            icon: Icons.folder_open_outlined,
            onTapOverride: _pickLocalAudio,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
