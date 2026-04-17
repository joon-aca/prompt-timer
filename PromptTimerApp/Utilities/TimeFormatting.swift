import Foundation

public enum TimeFormatting {
    public static func timerName(label: String?, durationSeconds: Int) -> String {
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedLabel, !trimmedLabel.isEmpty {
            return trimmedLabel
        }
        return "\(shortDuration(durationSeconds)) timer"
    }

    public static func timerSummary(label: String?, action: TimerAction?, durationSeconds: Int) -> String {
        let name = timerName(label: label, durationSeconds: durationSeconds)
        guard let action else {
            return name
        }
        return "\(name) (\(action.summary))"
    }

    public static func shortDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainingSeconds = clamped % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if minutes > 0 {
            parts.append("\(minutes)m")
        }
        if remainingSeconds > 0 || parts.isEmpty {
            parts.append("\(remainingSeconds)s")
        }
        return parts.joined(separator: " ")
    }

    public static func dueTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public static func finishedBody(for timer: TimerEntry) -> String {
        let body = timerSummary(label: timer.label, action: nil, durationSeconds: timer.durationSeconds)
        if let action = timer.action {
            return "\(body) finished. Opening \(action.displayName ?? action.target)."
        }
        return "\(body) finished"
    }
}
