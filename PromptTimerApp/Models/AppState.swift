import Foundation

public struct AppState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var activeTimers: [TimerEntry]
    public var recentTimers: [TimerEntry]
    public var preferences: Preferences

    public init(
        schemaVersion: Int = AppState.currentSchemaVersion,
        activeTimers: [TimerEntry] = [],
        recentTimers: [TimerEntry] = [],
        preferences: Preferences = Preferences()
    ) {
        self.schemaVersion = schemaVersion
        self.activeTimers = activeTimers
        self.recentTimers = recentTimers
        self.preferences = preferences
    }
}
