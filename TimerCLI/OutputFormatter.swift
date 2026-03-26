import Foundation
import PromptTimerCore

public enum OutputMode {
    case terminal
    case alfred
}

public enum OutputFormatter {
    public static let helpText = """
    Prompt Timer

    Usage:
      timer 10
      timer 25 deep work
      timer 30s tea
      timer 1h30m writing
      timer list
      timer ls
      timer status
      timer cancel
      timer cancel all
      timer cancel <id>
      timer test
      timer open
      timer help

    Options:
      --verbose   Print IPC and launch debug output to stderr
    """

    public static func render(_ response: IPCResponse, mode: OutputMode) -> String {
        switch mode {
        case .alfred:
            return response.message
        case .terminal:
            guard !response.timers.isEmpty else {
                return response.message
            }

            let lines = response.timers.map { timer in
                let label = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
                let remaining = TimeFormatting.shortDuration(timer.remainingSeconds)
                return "\(label)  \(remaining)"
            }

            return ([response.message] + lines).joined(separator: "\n")
        }
    }
}
