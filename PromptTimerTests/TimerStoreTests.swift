import Foundation
import Testing
@testable import PromptTimerCore

@Test func savesAndLoadsState() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

    let stateURL = directory.appendingPathComponent("state.json")
    let store = AtomicFileStore<AppState>(fileURL: stateURL)
    let state = AppState(
        activeTimers: [
            TimerEntry(
                id: "abc123",
                label: "focus",
                createdAt: Date(timeIntervalSince1970: 0),
                dueAt: Date(timeIntervalSince1970: 100),
                durationSeconds: 60
            ),
        ],
        recentTimers: [],
        preferences: Preferences()
    )

    try store.save(state)
    let loaded = try store.load()

    #expect(loaded == state)
}

@Test func backsUpCorruptState() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

    let stateURL = directory.appendingPathComponent("state.json")
    try "not-json".data(using: .utf8)?.write(to: stateURL)

    let store = AtomicFileStore<AppState>(fileURL: stateURL)
    let backup = try store.backupCorruptFile()

    #expect(backup != nil)
    #expect(FileManager.default.fileExists(atPath: backup!.path))
}
