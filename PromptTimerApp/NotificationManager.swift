import AppKit
import Foundation
import PromptTimerCore
import UserNotifications

@MainActor
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var onStatusChange: ((UNAuthorizationStatus) -> Void)?

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            let authorizationStatus = settings.authorizationStatus
            Task { @MainActor in
                self?.authorizationStatus = authorizationStatus
                self?.onStatusChange?(authorizationStatus)
            }
        }
    }

    func requestAuthorizationIfNeeded(completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard authorizationStatus == .notDetermined else {
            completion?()
            return
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshAuthorizationStatus()
                completion?()
            }
        }
    }

    func sendCompletionNotification(for timer: TimerEntry, playSound: Bool, soundName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Timer"
        content.body = TimeFormatting.finishedBody(for: timer)
        if playSound, authorizationStatus == .authorized {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }

        let request = UNNotificationRequest(
            identifier: "prompttimer.\(timer.id).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)

        // Play sound directly only when notifications are denied/not determined,
        // since UNNotificationSound handles it when authorized
        if playSound, authorizationStatus != .authorized {
            Self.playSound(named: soundName)
        }
    }

    func sendTestNotification(playSound: Bool, soundName: String) {
        let timer = TimerEntry(label: "Test timer", dueAt: Date(), durationSeconds: 60)
        sendCompletionNotification(for: timer, playSound: playSound, soundName: soundName)
    }

    static func statusMessage(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional:
            return "Notifications are on. You will get native alerts when timers finish."
        case .denied:
            return "Notifications are off. Prompt Timer will still flash in the menu bar and can still play sound locally."
        case .notDetermined:
            return "Prompt Timer will ask for notifications the first time you start a timer."
        @unknown default:
            return "Notification status is unavailable."
        }
    }

    static func playSound(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    static let availableSounds: [String] = {
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "aiff" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }()
}
