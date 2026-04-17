import Foundation

public struct TimerEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String?
    public var createdAt: Date
    public var dueAt: Date
    public var durationSeconds: Int
    public var state: TimerState

    public init(
        id: String? = nil,
        label: String? = nil,
        createdAt: Date = Date(),
        dueAt: Date,
        durationSeconds: Int,
        state: TimerState = .active
    ) {
        self.id = id ?? Self.makeID()
        self.label = label?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
        self.dueAt = dueAt
        self.durationSeconds = durationSeconds
        self.state = state
    }

    public func remainingSeconds(referenceDate: Date = Date()) -> Int {
        max(0, Int(dueAt.timeIntervalSince(referenceDate)))
    }

    public func finishedVersion() -> TimerEntry {
        var copy = self
        copy.state = .finished
        return copy
    }

    public func cancelledVersion() -> TimerEntry {
        var copy = self
        copy.state = .cancelled
        return copy
    }

    public func matchesRecentHistoryTemplate(_ other: TimerEntry) -> Bool {
        label == other.label &&
            durationSeconds == other.durationSeconds
    }

    private static func makeID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
