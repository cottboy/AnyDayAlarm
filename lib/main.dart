import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/alarm_repository.dart';
import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';
import 'pages/ringing_page.dart';
import 'services/alarm_platform.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 响铃会话状态：区分"贪睡后再响"与"新的一次触发"，用于贪睡次数上限的累计与重置。
class RingSession {
  /// 当前响铃会话已贪睡次数
  static int snoozeUsed = 0;

  /// Flutter 发起贪睡的时间 + 间隔，用于判定本次响铃是否为贪睡触发
  static DateTime? pendingSnoozeUntil;

  /// 是否存在尚未触发的贪睡（用于区分贪睡再响与新触发）
  static bool get awaitingSnoozeRing => pendingSnoozeUntil != null;

  static void markSnooze(int minutes) {
    snoozeUsed += 1;
    pendingSnoozeUntil = DateTime.now().add(Duration(minutes: minutes));
  }

  static void reset() {
    snoozeUsed = 0;
    pendingSnoozeUntil = null;
  }
}

/// 响铃页是否已打开（防止重复压栈）。
bool _ringingPageOpen = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await AlarmRepository.load();

  // 启动自愈：一次性闹钟若已过期则禁用，避免列表中出现永不响铃的"启用"闹钟
  final now = DateTime.now();
  final expired = repo.alarms
      .where((a) => a.enabled && a.nextTriggerAt(now) == null)
      .toList();
  for (final a in expired) {
    a.enabled = false;
    await repo.save(a);
  }
  // 全量同步到原生（覆盖开机后触发丢失、数据修复等场景）
  await AlarmPlatform.syncAndScheduleAll(repo.alarms);

  // 原生推送的响铃事件（进程存活时由响铃服务通知）
  AlarmPlatform.setEventHandler((call) async {
    if (call.method == 'onAlarmRing' && call.arguments is String) {
      openRingingPage(call.arguments as String);
    }
    return null;
  });

  runApp(AnyDayAlarmApp(repository: repo));

  // 冷启动时若已有正在响铃的闹钟，进入后直接弹响铃页
  unawaited(_restoreRingingIfNeeded());
}

Future<void> _restoreRingingIfNeeded() async {
  try {
    final ringingId = await AlarmPlatform.pendingRingingAlarm();
    if (ringingId != null && ringingId.isNotEmpty) {
      // 给首页一帧的挂载时间
      Timer(const Duration(milliseconds: 300), () => openRingingPage(ringingId));
    }
  } catch (_) {
    // 原生不可用时静默跳过
  }
}

void openRingingPage(String alarmId) {
  if (_ringingPageOpen) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  _ringingPageOpen = true;
  nav.pushNamed('/ringing', arguments: alarmId).whenComplete(() {
    _ringingPageOpen = false;
  });
}

class AnyDayAlarmApp extends StatelessWidget {
  const AnyDayAlarmApp({super.key, required this.repository});

  final AlarmRepository repository;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return MaterialApp(
      title: 'AnyDayAlarm',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6BFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/ringing':
            final alarmId = settings.arguments;
            if (alarmId is! String || alarmId.isEmpty) {
              return MaterialPageRoute<void>(
                builder: (_) => HomePage(repository: repository),
              );
            }
            return MaterialPageRoute<void>(
              builder: (_) => RingingPage(repository: repository, alarmId: alarmId),
              settings: settings,
            );
          case '/':
          default:
            return MaterialPageRoute<void>(
              builder: (_) => HomePage(repository: repository),
              settings: const RouteSettings(name: '/'),
            );
        }
      },
    );
  }
}
