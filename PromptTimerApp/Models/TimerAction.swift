import Foundation

public enum TimerActionKind: String, Codable, Sendable {
    case launchApplication
}

public struct TimerAction: Codable, Equatable, Sendable {
    public var kind: TimerActionKind
    public var target: String
    public var displayName: String?

    public init(kind: TimerActionKind, target: String, displayName: String? = nil) {
        self.kind = kind
        self.target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    public static func launchApplication(target: String, displayName: String? = nil) -> TimerAction {
        TimerAction(kind: .launchApplication, target: target, displayName: displayName)
    }

    public var summary: String {
        switch kind {
        case .launchApplication:
            return "launch \(displayName ?? target)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
