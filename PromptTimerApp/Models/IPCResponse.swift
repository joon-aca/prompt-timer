import Foundation

public struct IPCTimerSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String?
    public var durationSeconds: Int
    public var remainingSeconds: Int
    public var dueAt: Date
    public var state: TimerState

    public init(
        id: String,
        label: String?,
        durationSeconds: Int,
        remainingSeconds: Int,
        dueAt: Date,
        state: TimerState
    ) {
        self.id = id
        self.label = label
        self.durationSeconds = durationSeconds
        self.remainingSeconds = remainingSeconds
        self.dueAt = dueAt
        self.state = state
    }
}

public struct IPCResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var message: String
    public var timers: [IPCTimerSnapshot]

    public init(ok: Bool, message: String, timers: [IPCTimerSnapshot] = []) {
        self.ok = ok
        self.message = message
        self.timers = timers
    }

    public static func success(_ message: String, timers: [IPCTimerSnapshot] = []) -> IPCResponse {
        IPCResponse(ok: true, message: message, timers: timers)
    }

    public static func failure(_ message: String) -> IPCResponse {
        IPCResponse(ok: false, message: message)
    }
}

public enum IPCCodec {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
