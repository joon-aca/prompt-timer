import Foundation
import OSLog

public struct PromptTimerLogger: Sendable {
    private let logger: Logger
    private static let verboseEnabled = ProcessInfo.processInfo.environment["PROMPTTIMER_VERBOSE"] == "1"

    public init(category: String) {
        logger = Logger(subsystem: "PromptTimer", category: category)
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    public func debug(_ message: String) {
        guard Self.verboseEnabled else {
            return
        }
        logger.debug("\(message, privacy: .public)")
    }
}
