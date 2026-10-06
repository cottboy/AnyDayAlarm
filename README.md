# AnyDayAlarm · 任意日期闹钟

一款支持**自定义任意日期任意时间响铃**的跨平台闹钟应用。市面上的闹钟大多只能设置每周重复，而日历日程又不会响铃——本项目补上这个空缺：一次性日期闹钟与普通重复闹钟使用同一套调度体系，功能完整。

## 功能

- **任意日期闹钟**：指定未来任何一天的任何时间响铃（核心能力）
- **重复闹钟**：每天 / 每周自定义几天 / **每年 / 每月**（后两者支持公历与农历基准）
- **农历闹钟**：基于寿星天文历算法（`lunar` 库，支持公元 1–9999 年），一次性农历日期、每年/每月农历重复；"三十"遇小月自动提前一天，每年重复默认忽略闰月（可选仅在闰月年触发）；原生调度层通过预计算触发点数组实现兜底重排，自身无需理解农历
- **贪睡**：可配置间隔（1–30 分钟）与次数（0–10 次，0 为禁止贪睡）
- **铃声**：4 个内置铃声（经典/电子脉冲/编钟/渐强）+ 本地音频导入，支持试听
- **音量渐强**：响铃时从静音在 60 秒内逐步增强
- **震动**：可与铃声叠加
- **标签颜色**：6 种颜色区分不同用途的闹钟
- **可靠性**：精确闹钟调度、开机自动重排、权限降级兜底、5 分钟无人处理自动停止

## 技术架构

```
Flutter UI（列表 / 编辑 / 响铃页，中文界面走 arb 翻译文件）
        │  MethodChannel: any_day_alarm/native
        ▼
┌─ Android ─────────────────────────────┐   ┌─ iOS ─────────────────────────┐
│ AlarmManager 精确闹钟（USE_EXACT_ALARM）│   │ iOS 26+：AlarmKit（系统级闹钟） │
│ AlarmReceiver → AlarmRingService      │   │ iOS < 26：本地通知（时效性）     │
│ （前台服务：铃声+震动+全屏意图通知）      │   │ （降级路径）                   │
│ BootReceiver：开机/升级后重排           │   │                               │
└───────────────────────────────────────┘   └───────────────────────────────┘
```

调度核心抽象：调度器只关心"下一次触发的时间点"。重复闹钟触发后由原生侧立即排定下一次（不依赖 App 存活）；一次性闹钟是规则最简单的特例。数据纯本地存储（shared_preferences + 原生调度镜像文件），无账号无网络。

### Android 可靠性设计

- `USE_EXACT_ALARM` 权限：安装即授予且用户不可撤销（闹钟类应用专用）
- 触发链路：`AlarmManager.setExactAndAllowWhileIdle` → `AlarmReceiver` → 前台服务响铃（与 UI 解耦，页面未弹出铃声也照响）
- 全屏意图通知：锁屏上直接弹响铃界面（`showWhenLocked` + `turnScreenOn`）
- 无精确权限时自动降级为 ±10 分钟窗口调度
- 引导忽略电池优化（国产 ROM 省电策略兜底）

## 构建

```bash
flutter pub get
flutter analyze     # 静态检查
flutter test        # 单元测试（闹钟触发规则）
flutter build apk --release   # 产物在 build/app/outputs/flutter-apk/
```

## iOS 端说明（M3 预留）

`ios/Runner/AlarmScheduler.swift` 已实现完整的双策略调度（AlarmKit + 本地通知降级）与通道对接，但 **Windows 环境无法编译 iOS**，需要在 macOS + Xcode 26 上完成首次编译：

1. 用 Xcode 打开 `ios/Runner.xcworkspace`，首次编译时对照 AlarmKit SDK 校正代码中标注 `[API-CHECK]` 的位置（AlarmKit API 细节以 iOS 26 SDK 为准）
2. 在 Signing & Capabilities 中添加 AlarmKit 相关 entitlement
3. `ios/Runner/Ringtones/` 下的铃声文件确认已包含在 target 中（新工程使用文件系统同步分组，放入目录即自动包含）
4. iOS 响铃 UI 由 AlarmKit 的系统 Live Activity 呈现，无需 Flutter 响铃页

## 项目结构

```
lib/
  main.dart                  # 入口、路由、响铃事件桥接
  models/alarm.dart          # 闹钟实体 + 下次触发时间规则 + JSON 防御性解析
  lunar/lunar_helper.dart    # 农历规则封装（闰月策略、三十缺失、年/月触发推算）
  data/alarm_repository.dart # 本地持久化
  services/alarm_platform.dart # 原生通道封装（含 futureTriggers 预计算下发）
  pages/home_page.dart       # 列表 + 权限引导横幅
  pages/edit_page.dart       # 编辑/新建（频率×日历基准组合、铃声试听、贪睡、渐强、颜色）
  pages/calendar_picker_sheet.dart # 农历/公历轮子选择器
  pages/ringing_page.dart    # 全屏响铃页
  l10n/                      # 中英文翻译（app_zh.arb 为模板）
android/.../kotlin/          # 调度器、触发接收器、响铃服务、开机重排
ios/Runner/                  # AlarmKit 集成（待 Mac 编译验证）
tool/gen_ringtones.py        # 内置铃声合成脚本
```
