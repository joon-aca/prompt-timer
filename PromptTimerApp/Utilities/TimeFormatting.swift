import Foundation

public enum TimeFormatting {
    public static func timerName(label: String?, durationSeconds: Int) -> String {
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedLabel, !trimmedLabel.isEmpty {
            return trimmedLabel
        }
        return "\(shortDuration(durationSeconds)) timer"
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
        if let label = timer.label {
            return "\(label) finished"
        }
        return "\(shortDuration(timer.durationSeconds)) timer finished"
    }
}
