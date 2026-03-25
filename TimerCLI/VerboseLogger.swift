import Foundation

public enum VerboseLogger {
    private static let key = "PROMPTTIMER_VERBOSE"

    public static func setEnabled(_ value: Bool) {
        setenv(key, value ? "1" : "0", 1)
    }

    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[key] == "1"
    }

    public static func log(_ message: String) {
        guard isEnabled else {
            return
        }
        fputs("[timer] \(message)\n", stderr)
    }
}
