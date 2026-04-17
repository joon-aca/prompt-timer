import Foundation
import Testing
@testable import PromptTimerCore

@MainActor
@Test func addsAndCancelsTimers() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempStore = try TimerStore(fileManager: .default, baseDirectory: directory)
    let manager = TimerManager(store: tempStore, now: { Date(timeIntervalSince1970: 0) })

    manager.load()
    let timer = manager.startTimer(durationSeconds: 600, label: "focus")
    #expect(manager.listActiveTimers().count >= 1)

    _ = manager.cancelTimer(id: timer.id)
    #expect(manager.listActiveTimers().contains(where: { $0.id == timer.id }) == false)
}

@MainActor
@Test func selectsNextDueTimer() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempStore = try TimerStore(fileManager: .default, baseDirectory: directory)
    let manager = TimerManager(store: tempStore, now: { Date(timeIntervalSince1970: 0) })

    manager.load()
    let first = manager.startTimer(durationSeconds: 120, label: "tea")
    let second = manager.startTimer(durationSeconds: 600, label: "focus")

    #expect(manager.nextDueTimer()?.id == first.id)
    #expect(manager.nextDueTimer()?.id != second.id)
}

@MainActor
@Test func reconcilesOverdueTimers() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempStore = try TimerStore(fileManager: .default, baseDirectory: directory)
    let manager = TimerManager(store: tempStore, now: { Date(timeIntervalSince1970: 500) })

    manager.load()
    _ = manager.startTimer(durationSeconds: 60, label: "short")
    manager.reconcile(referenceDate: Date(timeIntervalSince1970: 1_000))

    #expect(manager.listActiveTimers().isEmpty)
    #expect(manager.listRecentTimers().count >= 1)
}

@MainActor
@Test func restartRecentTimerCreatesNewActiveTimer() throws {
    var currentTime = Date(timeIntervalSince1970: 0)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempStore = try TimerStore(fileManager: .default, baseDirectory: directory)
    let manager = TimerManager(store: tempStore, now: { currentTime })

    manager.load()
    let original = manager.startTimer(durationSeconds: 300, label: "stretch")
    currentTime = Date(timeIntervalSince1970: 600)
    manager.reconcile(referenceDate: currentTime)

    let restarted = try #require(manager.restartRecentTimer(id: original.id))

    #expect(restarted.id != original.id)
    #expect(restarted.label == original.label)
    #expect(restarted.durationSeconds == original.durationSeconds)
    #expect(manager.listActiveTimers().contains(where: { $0.id == restarted.id }))
}

@MainActor
@Test func deduplicatesRecentTimersByTemplate() throws {
    var currentTime = Date(timeIntervalSince1970: 0)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempStore = try TimerStore(fileManager: .default, baseDirectory: directory)
    let manager = TimerManager(store: tempStore, now: { currentTime })

    manager.load()

    _ = manager.startTimer(durationSeconds: 300, label: "tea")
    currentTime = Date(timeIntervalSince1970: 600)
    manager.reconcile(referenceDate: currentTime)

    _ = manager.startTimer(durationSeconds: 300, label: "tea")
    currentTime = Date(timeIntervalSince1970: 1200)
    manager.reconcile(referenceDate: currentTime)

    _ = manager.startTimer(durationSeconds: 180, label: "focus")
    currentTime = Date(timeIntervalSince1970: 1500)
    manager.reconcile(referenceDate: currentTime)

    let recentTimers = manager.listRecentTimers()
    #expect(recentTimers.count == 2)
    #expect(recentTimers.filter { $0.label == "tea" && $0.durationSeconds == 300 }.count == 1)
}

@MainActor
@Test func usesDurationAsFallbackTimerNameInStatus() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let tempStore = try TimerStore(fileManager: .default, baseDirectory: directory)
    let manager = TimerManager(store: tempStore, now: { Date(timeIntervalSince1970: 0) })

    manager.load()
    _ = manager.startTimer(durationSeconds: 180, label: nil)

    #expect(manager.statusMessage(referenceDate: Date(timeIntervalSince1970: 0)).contains("3m timer"))
}
