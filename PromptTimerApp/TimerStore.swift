import Darwin
import Foundation

public struct TimerStore {
    private static let appBundleIdentifier = "com.joon.prompttimer"

    public let appSupportDirectory: URL
    public let stateFileURL: URL
    public let socketPath: String
    private let logger = PromptTimerLogger(category: "TimerStore")
    private let fileStore: AtomicFileStore<AppState>

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) throws {
        let directory: URL
        if let baseDirectory {
            directory = baseDirectory
        } else {
            let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            let containerRoot = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Containers", isDirectory: true)
                .appendingPathComponent(Self.appBundleIdentifier, isDirectory: true)
                .appendingPathComponent("Data", isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
            directory = containerRoot.appendingPathComponent("PromptTimer", isDirectory: true)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        appSupportDirectory = directory
        stateFileURL = directory.appendingPathComponent("state.json")
        fileStore = AtomicFileStore<AppState>(fileURL: stateFileURL)

        let tmpDir = NSTemporaryDirectory()
        socketPath = (tmpDir as NSString).appendingPathComponent("\(Self.appBundleIdentifier).sock")
    }

    public func loadState() -> AppState {
        do {
            guard let state = try fileStore.loadIfPresent() else {
                return AppState()
            }
            if state.schemaVersion != AppState.currentSchemaVersion {
                logger.info("Unsupported schema version \(state.schemaVersion). Resetting to defaults.")
                return AppState()
            }
            return state
        } catch {
            logger.error("Failed to load state: \(error.localizedDescription)")
            _ = try? fileStore.backupCorruptFile()
            return AppState()
        }
    }

    public func saveState(_ state: AppState) {
        do {
            try fileStore.save(state)
        } catch {
            logger.error("Failed to save state: \(error.localizedDescription)")
        }
    }
}
