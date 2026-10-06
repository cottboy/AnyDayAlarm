import 'dart:async';

import 'package:flutter/material.dart';

import '../data/alarm_repository.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/alarm.dart';
import '../services/alarm_platform.dart';

/// 全屏响铃页：闹钟到点时由原生推送进入（或冷启动恢复）。
/// 不允许返回手势退出，必须点"停止"或"贪睡"。
class RingingPage extends StatefulWidget {
  const RingingPage({super.key, required this.repository, required this.alarmId});

  final AlarmRepository repository;
  final String alarmId;

  @override
  State<RingingPage> createState() => _RingingPageState();
}

class _RingingPageState extends State<RingingPage> {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  bool _acting = false;

  Alarm? _alarm;

  @override
  void initState() {
    super.initState();
    _alarm = widget.repository.byId(widget.alarmId);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // 非贪睡触发视为新一轮会话，重置贪睡计数
    if (!RingSession.awaitingSnoozeRing) {
      RingSession.reset();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  bool get _canSnooze {
    final alarm = _alarm;
    if (alarm == null) return false;
    return alarm.snoozeCount > 0 && RingSession.snoozeUsed < alarm.snoozeCount;
  }

  Future<void> _stop() async {
    if (_acting) return;
    _acting = true;
    try {
      await AlarmPlatform.stopRinging(widget.alarmId);
      final alarm = _alarm;
      if (alarm != null && alarm.repeatType == RepeatType.once && alarm.enabled) {
        // 一次性闹钟响过即完成
        alarm.enabled = false;
        await widget.repository.save(alarm);
        await AlarmPlatform.syncAndScheduleAll(widget.repository.alarms);
      }
      RingSession.reset();
    } finally {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _snooze() async {
    if (_acting || !_canSnooze) return;
    _acting = true;
    final minutes = _alarm?.snoozeMinutes ?? 5;
    RingSession.markSnooze(minutes);
    try {
      await AlarmPlatform.snoozeRinging(widget.alarmId, minutes);
    } finally {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.toastSnoozed(minutes))));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = _alarm != null ? Color(_alarm!.colorValue) : scheme.primary;
    final label = _alarm?.label ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12131A),
                Color.fromARGB(
                  255,
                  (accent.r * 255 * 0.35).round() + 18,
                  (accent.g * 255 * 0.35).round() + 19,
                  (accent.b * 255 * 0.45).round() + 26,
                ),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Icon(
                  Icons.alarm_on_rounded,
                  size: 56,
                  color: accent.withAlpha(230),
                ),
                const SizedBox(height: 24),
                Text(
                  _formatClock(),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 28),
                if (label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RingButton(
                          label: l10n.ringSnooze,
                          icon: Icons.snooze_rounded,
                          enabled: _canSnooze,
                          onTap: _snooze,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _RingButton(
                          label: l10n.ringStop,
                          icon: Icons.alarm_off_rounded,
                          filled: true,
                          accent: accent,
                          onTap: _stop,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatClock() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate() {
    final y = _now.year;
    final mo = _now.month;
    final d = _now.day;
    return '$y/$mo/$d';
  }
}

class _RingButton extends StatelessWidget {
  const _RingButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.accent,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color? accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? Theme.of(context).colorScheme.primary;
    final child = FilledButton.icon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: filled ? accentColor : Colors.white.withAlpha(31),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
    return child;
  }
}
