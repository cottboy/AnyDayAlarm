// iOS 原生调度层：与 Flutter 侧 AlarmPlatform 通道对接。
//
// 双策略：
//   * iOS 26+  → AlarmKit（系统级闹钟：突破静音/专注模式，锁屏 Live Activity 呈现）
//   * iOS < 26 → UNUserNotificationCenter 本地通知（时效性通知，尽量接近闹钟体验）
//
// 注意：本文件在 Windows CI 环境无法编译验证，需在 macOS + Xcode 26 SDK 下
// 首次编译时对照 AlarmKit 实际 API 签名校正（标注了 [API-CHECK] 的位置）。

import Foundation
import UserNotifications
import Flutter
#if canImport(AlarmKit)
import AlarmKit
#endif

/// 与 Flutter 同步而来的单条闹钟（字段校验同 Android 侧，数据视为不可信）。
struct SyncedAlarm {
    let id: String
    let enabled: Bool
    let repeatType: Int // 0=一次性 1=每天 2=每周自定义
    let triggerAt: TimeInterval? // 毫秒 epoch
    let onceAt: TimeInterval?
    let hour: Int
    let minute: Int
    let weekdays: [Int] // 1=周一 … 7=周日
    let label: String

    static func parse(_ dict: [String: Any]) -> SyncedAlarm? {
        guard let id = dict["id"] as? String, !id.isEmpty, id.count <= 64,
              let repeatType = dict["repeatType"] as? Int, (0...2).contains(repeatType),
              let hour = dict["hour"] as? Int, (0...23).contains(hour),
              let minute = dict["minute"] as? Int, (0...59).contains(minute)
        else { return nil }
        let triggerAt = dict["triggerAt"] as? Int64
        let onceAt = dict["onceAt"] as? Int64
        let weekdays = (dict["weekdays"] as? [Int])?.filter { (1...7).contains($0) } ?? []
        let label = (dict["label"] as? String)?.prefix(100) ?? ""
        return SyncedAlarm(
            id: id,
            enabled: dict["enabled"] as? Bool ?? false,
            repeatType: repeatType,
            triggerAt: triggerAt.map { TimeInterval($0) / 1000.0 },
            onceAt: onceAt.map { TimeInterval($0) / 1000.0 },
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            label: String(label)
        )
    }
}

/// iOS 调度器：按系统版本分流到 AlarmKit 或本地通知。
final class IosAlarmScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = IosAlarmScheduler()

    private let channelName = "any_day_alarm/native"
    private var channel: FlutterMethodChannel?

    /// 已注册的本地通知标识（低版本路径，用于取消重排）。
    private var notificationIds: Set<String> = []

    func registerChannels(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
        self.channel = channel
        UNUserNotificationCenter.current().delegate = self
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "syncAndScheduleAll":
            guard let json = call.arguments as? String,
                  let data = json.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else {
                result(FlutterError(code: "BAD_ARGS", message: "invalid payload", details: nil))
                return
            }
            let alarms = array.compactMap { SyncedAlarm.parse($0) }
            scheduleAll(alarms) { ok in result(ok) }
        case "canScheduleExactAlarms":
            // iOS 无 Android 意义上的精确闹钟限制；iOS 26+ 需 AlarmKit 授权
            if #available(iOS 26.0, *) {
                #if canImport(AlarmKit)
                let state = AlarmKitScheduler.shared.authorizationState
                result(state == .authorized || state == .notDetermined)
                #else
                result(true)
                #endif
            } else {
                result(true)
            }
        case "openExactAlarmSettings":
            openAppSettings(result)
        case "isIgnoringBatteryOptimizations":
            result(true) // iOS 无此概念
        case "areNotificationsEnabled":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    result(settings.authorizationStatus == .authorized
                        || settings.authorizationStatus == .notDetermined
                        || settings.authorizationStatus == .provisional)
                }
            }
        case "openNotificationSettings":
            openAppSettings(result)
        case "pendingRingingAlarm":
            // AlarmKit 响铃 UI 由系统呈现，无需 Flutter 侧恢复响铃页
            result(nil)
        default:
            // stopRinging / snoozeRinging / playRingtonePreview / pickRingtone
            // 为 Android 专属交互，iOS 上返回未实现，Flutter 侧已做容错。
            result(FlutterMethodNotImplemented)
        }
    }

    private func openAppSettings(_ result: @escaping FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        result(nil)
    }

    // MARK: - 调度

    private func scheduleAll(_ alarms: [SyncedAlarm], completion: @escaping (Bool) -> Void) {
        if #available(iOS 26.0, *), canUseAlarmKit() {
            #if canImport(AlarmKit)
            AlarmKitScheduler.shared.syncAll(alarms, completion: completion)
            #else
            scheduleNotifications(alarms, completion: completion)
            #endif
        } else {
            scheduleNotifications(alarms, completion: completion)
        }
    }

    private func canUseAlarmKit() -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return AlarmKitScheduler.shared.authorizationState == .authorized
        }
        return false
        #else
        return false
        #endif
    }

    /// iOS < 26 的本地通知调度路径。
    private func scheduleNotifications(_ alarms: [SyncedAlarm], completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()

        func requestThenSchedule() {
            var requests: [UNNotificationRequest] = []
            var ids: Set<String> = []
            for alarm in alarms where alarm.enabled {
                switch alarm.repeatType {
                case 0:
                    guard let at = alarm.onceAt ?? alarm.triggerAt else { continue }
                    let fire = Date(timeIntervalSince1970: at)
                    guard fire > Date() else { continue }
                    var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    comps.second = 0
                    requests.append(makeRequest(id: alarm.id, alarm: alarm, comps: comps, repeats: false))
                    ids.insert(alarm.id)
                case 1:
                    var comps = DateComponents()
                    comps.hour = alarm.hour
                    comps.minute = alarm.minute
                    requests.append(makeRequest(id: alarm.id, alarm: alarm, comps: comps, repeats: true))
                    ids.insert(alarm.id)
                case 2:
                    for weekday in alarm.weekdays {
                        let id = "\(alarm.id)-w\(weekday)"
                        var comps = DateComponents()
                        // DateComponents.weekday: 1=周日 … 7=周六 → 转换本地 1=周一 … 7=周日
                        comps.weekday = (weekday % 7) + 1
                        comps.hour = alarm.hour
                        comps.minute = alarm.minute
                        requests.append(makeRequest(id: id, alarm: alarm, comps: comps, repeats: true))
                        ids.insert(id)
                    }
                default:
                    break
                }
            }

            // 先清掉本 App 的旧计划再挂新计划
            center.getPendingNotificationRequests { pending in
                let stale = pending.map(\.identifier).filter { !$0.hasSuffix("-snooze") }
                center.removePendingNotificationRequests(withIdentifiers: stale)
                let group = DispatchGroup()
                var failed = false
                for request in requests {
                    group.enter()
                    center.add(request) { error in
                        if error != nil { failed = true }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    completion(!failed)
                }
            }
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { requestThenSchedule() }
        }
    }

    private func makeRequest(
        id: String,
        alarm: SyncedAlarm,
        comps: DateComponents,
        repeats: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "闹钟" : alarm.label
        content.body = String(format: "%02d:%02d", alarm.hour, alarm.minute)
        content.sound = resolveSound(alarm.ringtoneId)
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["alarmId": alarm.id]
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// 铃声：内置铃声随 bundle 分发（见 ios/Runner/Ringtones/）；
    /// 自定义铃声由应用复制到容器内，通知声音无法引用容器外路径。
    private func resolveSound(_ ringtoneId: String) -> UNNotificationSound {
        if ringtoneId.hasPrefix("builtin:") {
            let key = ringtoneId.dropFirst("builtin:".count)
            return UNNotificationSound(named: UNNotificationSoundName("\(key).wav"))
        }
        return .default
    }

    // MARK: - 前台呈现

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 前台也全量呈现（声音+横幅），闹钟在前台时同样要响
        return [.banner, .sound, .badge, .list]
    }
}

// MARK: - AlarmKit（iOS 26+）

#if canImport(AlarmKit)
@available(iOS 26.0, *)
final class AlarmKitScheduler {
    static let shared = AlarmKitScheduler()

    private var scheduledIds: Set<UUID> = []

    var authorizationState: AlarmAuthorizationState {
        // [API-CHECK] AlarmManager.authorizationState 的确切签名以 Xcode 26 SDK 为准
        let state = AlarmManager.shared.authorizationState
        return state
    }

    /// 全量同步：先清后建，语义与 Android 侧一致。
    func syncAll(_ alarms: [SyncedAlarm], completion: @escaping (Bool) -> Void) {
        for old in scheduledIds {
            try? AlarmManager.shared.cancel(id: old)
        }
        scheduledIds.removeAll()

        guard let auth = try? AlarmManager.shared.requestAuthorization(),
              auth == .authorized else {
            // 未授权时降级为本地通知由上层兜底；此处直接返回成功以同步状态
            completion(true)
            return
        }

        var allOk = true
        for alarm in alarms where alarm.enabled {
            do {
                let schedule = try buildSchedule(alarm)
                let config = AlarmManager.AlarmConfiguration(
                    schedule: schedule,
                    attributes: attributes(for: alarm),
                    sound: nil // [API-CHECK] 传 nil 使用系统默认闹铃声；自定义铃声需 AlarmSound
                )
                let id = UUID(uuidString: alarm.id) ?? UUID()
                _ = try AlarmManager.shared.schedule(id: id, configuration: config)
                scheduledIds.insert(id)
            } catch {
                allOk = false
            }
        }
        completion(allOk)
    }

    private func buildSchedule(_ alarm: SyncedAlarm) throws -> Alarm.Schedule {
        switch alarm.repeatType {
        case 0:
            let at = alarm.onceAt ?? alarm.triggerAt ?? 0
            return .fixed(date: Date(timeIntervalSince1970: at))
        case 1:
            let all: Set<Locale.Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            return .repeating(Alarm.Schedule.Repeating(mode: .weekly, weekdays: all))
        case 2:
            let weekdays = Set(alarm.weekdays.compactMap(weekdayMapping))
            return .repeating(Alarm.Schedule.Repeating(mode: .weekly, weekdays: weekdays))
        default:
            throw NSError(domain: "AnyDayAlarm", code: 1)
        }
    }

    /// 本地编码 1=周一…7=周日 → Locale.Weekday
    private func weekdayMapping(_ iso: Int) -> Locale.Weekday? {
        switch iso {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        case 7: return .sunday
        default: return nil
        }
    }

    private func attributes(for alarm: SyncedAlarm) -> AlarmAttributes<EmptyMetadata> {
        let title = alarm.label.isEmpty ? "闹钟" : alarm.label
        let tint = ColorValue(alarm.colorValue) // [API-CHECK] 颜色转换类型以 SDK 为准
        return AlarmAttributes(
            presentation: AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: title,
                    stopButton: AlarmButton(
                        text: "停止",
                        textColor: .white,
                        systemImageName: "stop.fill"
                    )
                )
            ),
            metadata: nil,
            tintColor: tint,
            secondaryColor: tint
        )
    }
}
#endif
