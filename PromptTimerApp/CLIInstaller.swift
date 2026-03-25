import AppKit
import Foundation

enum CLIInstaller {
    static let linkPath = "/usr/local/bin/timer"

    static var isInstalled: Bool {
        let fm = FileManager.default
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: linkPath) else {
            return false
        }
        return dest == cliSourcePath
    }

    static var cliSourcePath: String {
        Bundle.main.bundlePath + "/Contents/Resources/timer"
    }

    /// Prompts for admin privileges and creates the symlink.
    /// Returns a user-facing message describing the result.
    @MainActor
    static func install() -> String {
        let script = """
        do shell script "mkdir -p /usr/local/bin && ln -sf '\(cliSourcePath)' '\(linkPath)'" \
            with administrator privileges
        """

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            if message.contains("canceled") || message.contains("-128") {
                return "Installation cancelled."
            }
            return "Installation failed: \(message)"
        }

        return isInstalled ? "CLI installed at \(linkPath)" : "Installation may have failed — check your PATH."
    }

    @MainActor
    static func uninstall() -> String {
        let script = """
        do shell script "rm -f '\(linkPath)'" with administrator privileges
        """

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)

        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return "Uninstall failed: \(message)"
        }

        return "CLI removed from \(linkPath)"
    }
}
