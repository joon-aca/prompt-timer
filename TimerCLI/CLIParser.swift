import Foundation
import PromptTimerCore

public enum ParsedCLICommand: Equatable {
    case help
    case ipc(IPCCommand)
}

enum CLIParserError: LocalizedError, Equatable {
    case missingCommand
    case unknownCommand(String)
    case invalidDuration(String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "Usage: timer 10 | timer list | timer status | timer cancel <id>"
        case let .unknownCommand(value):
            return "Unknown command: \(value)"
        case let .invalidDuration(value):
            return "Invalid duration. Use 10, 25m, 30s, or 1h30m. Input: \(value)"
        }
    }
}

public enum CLIParser {
    public static func parse(arguments: [String]) throws -> ParsedCLICommand {
        let tokens = arguments.flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
        guard let first = tokens.first else {
            return .help
        }

        switch first.lowercased() {
        case "help", "--help", "-h":
            return .help
        case "list", "ls":
            return .ipc(.list())
        case "status":
            return .ipc(.status())
        case "test":
            return .ipc(.test())
        case "open":
            return .ipc(.open())
        case "cancel":
            if tokens.count == 1 {
                return .ipc(.cancel())
            }
            let value = tokens.dropFirst().joined(separator: " ")
            if value.lowercased() == "all" {
                return .ipc(.cancelAll())
            }
            return .ipc(.cancel(id: value))
        default:
            do {
                let prompt = try TimerPromptParser.parse(tokens: tokens)
                return .ipc(.start(durationSeconds: prompt.durationSeconds, label: prompt.label, action: prompt.action))
            } catch {
                throw CLIParserError.invalidDuration(first)
            }
        }
    }
}
