import Foundation

public enum IPCCommandKind: String, Codable, Sendable {
    case start
    case list
    case status
    case cancel
    case cancelAll
    case test
    case open
}

public struct IPCCommand: Codable, Equatable, Sendable {
    public var command: IPCCommandKind
    public var durationSeconds: Int?
    public var label: String?
    public var action: TimerAction?
    public var id: String?

    public init(
        command: IPCCommandKind,
        durationSeconds: Int? = nil,
        label: String? = nil,
        action: TimerAction? = nil,
        id: String? = nil
    ) {
        self.command = command
        self.durationSeconds = durationSeconds
        self.label = label
        self.action = action
        self.id = id
    }

    public static func start(durationSeconds: Int, label: String?, action: TimerAction? = nil) -> IPCCommand {
        IPCCommand(command: .start, durationSeconds: durationSeconds, label: label, action: action)
    }

    public static func list() -> IPCCommand {
        IPCCommand(command: .list)
    }

    public static func status() -> IPCCommand {
        IPCCommand(command: .status)
    }

    public static func cancel(id: String? = nil) -> IPCCommand {
        IPCCommand(command: .cancel, id: id)
    }

    public static func cancelAll() -> IPCCommand {
        IPCCommand(command: .cancelAll)
    }

    public static func test() -> IPCCommand {
        IPCCommand(command: .test)
    }

    public static func open() -> IPCCommand {
        IPCCommand(command: .open)
    }
}
