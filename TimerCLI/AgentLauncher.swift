import Foundation

public enum AgentLauncher {
    public static func launchIfNeeded() {
        guard let appURL = discoverAppURL() else {
            VerboseLogger.log("No app bundle found for auto-launch")
            return
        }

        VerboseLogger.log("Launching app at \(appURL.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", appURL.path]
        do {
            try process.run()
        } catch {
            VerboseLogger.log("Failed to launch app: \(error.localizedDescription)")
        }
    }

    private static func discoverAppURL() -> URL? {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let bundledApp = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        if bundledApp.pathExtension == "app" {
            return bundledApp
        }

        let installedApp = URL(fileURLWithPath: "/Applications/Prompt Timer.app")
        if FileManager.default.fileExists(atPath: installedApp.path) {
            return installedApp
        }

        return nil
    }
}
