import Foundation

public enum TimerState: String, Codable, Sendable {
    case active
    case finished
    case cancelled
}
