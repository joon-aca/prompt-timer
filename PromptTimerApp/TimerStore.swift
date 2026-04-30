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
        let socketDirectory: URL
        if let baseDirectory {
            directory = baseDirectory
            socketDirectory = baseDirectory
        } else {
            let applicationSupportDirectory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = applicationSupportDirectory.appendingPathComponent("PromptTimer", isDirectory: true)
            socketDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: socketDirectory, withIntermediateDirectories: true, attributes: nil)
        appSupportDirectory = directory
        stateFileURL = directory.appendingPathComponent("state.json")
        fileStore = AtomicFileStore<AppState>(fileURL: stateFileURL)

        socketPath = socketDirectory.appendingPathComponent("\(Self.appBundleIdentifier).sock").path
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
