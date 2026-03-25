import Dispatch
import Foundation

@MainActor
public final class TimerManager {
    public private(set) var state: AppState

    public var onStateChange: ((AppState) -> Void)?
    public var onTimersFinished: (([TimerEntry]) -> Void)?
    public var onTick: (() -> Void)?

    private let store: TimerStore
    private let now: () -> Date
    private let logger = PromptTimerLogger(category: "TimerManager")
    private var dueTimer: DispatchSourceTimer?
    private var refreshTimer: DispatchSourceTimer?

    public init(
        store: TimerStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.now = now
        self.state = AppState()
    }

    deinit {
        dueTimer?.cancel()
        refreshTimer?.cancel()
    }

    public func load() {
        state = store.loadState()
        reconcile(referenceDate: now())
        refreshScheduling()
        onStateChange?(state)
    }

    public func startTimer(durationSeconds: Int, label: String?) -> TimerEntry {
        let creationDate = now()
        let timer = TimerEntry(
            label: label,
            createdAt: creationDate,
            dueAt: creationDate.addingTimeInterval(TimeInterval(durationSeconds)),
            durationSeconds: durationSeconds,
            state: .active
        )

        state.activeTimers.append(timer)
        sortState()
        persistState()
        refreshScheduling()
        onStateChange?(state)

        return timer
    }

    public func listActiveTimers() -> [TimerEntry] {
        state.activeTimers.sorted { $0.dueAt < $1.dueAt }
    }

    public func listRecentTimers() -> [TimerEntry] {
        state.recentTimers
    }

    public func nextDueTimer() -> TimerEntry? {
        listActiveTimers().first
    }

    @discardableResult
    public func cancelTimer(id: String) -> TimerEntry? {
        guard let index = state.activeTimers.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let cancelled = state.activeTimers.remove(at: index).cancelledVersion()
        persistState()
        refreshScheduling()
        onStateChange?(state)
        return cancelled
    }

    @discardableResult
    public func cancelOnlyTimerIfPossible() -> TimerEntry? {
        guard state.activeTimers.count == 1, let timer = state.activeTimers.first else {
            return nil
        }
        state.activeTimers.removeAll()
        persistState()
        refreshScheduling()
        onStateChange?(state)
        return timer.cancelledVersion()
    }

    public func cancelAllTimers() -> Int {
        let count = state.activeTimers.count
        state.activeTimers.removeAll()
        persistState()
        refreshScheduling()
        onStateChange?(state)
        return count
    }

    public func updatePreferences(_ mutate: (inout Preferences) -> Void) {
        mutate(&state.preferences)
        trimRecentHistory()
        persistState()
        refreshScheduling()
        onStateChange?(state)
    }

    public func handleWake() {
        reconcile(referenceDate: now())
        refreshScheduling()
        onStateChange?(state)
    }

    public func statusMessage(referenceDate: Date? = nil) -> String {
        let currentDate = referenceDate ?? now()
        let timers = listActiveTimers()

        guard let nextTimer = timers.first else {
            return "No active timers"
        }

        let label = TimeFormatting.timerName(label: nextTimer.label, durationSeconds: nextTimer.durationSeconds)
        let remaining = TimeFormatting.shortDuration(nextTimer.remainingSeconds(referenceDate: currentDate))
        return "\(timers.count) active timer(s). Next due: \(label) in \(remaining)"
    }

    public func snapshots(referenceDate: Date? = nil) -> [IPCTimerSnapshot] {
        let currentDate = referenceDate ?? now()
        return listActiveTimers().map {
            IPCTimerSnapshot(
                id: $0.id,
                label: $0.label,
                durationSeconds: $0.durationSeconds,
                remainingSeconds: $0.remainingSeconds(referenceDate: currentDate),
                dueAt: $0.dueAt,
                state: $0.state
            )
        }
    }

    public func reconcile(referenceDate: Date) {
        let overdue = state.activeTimers.filter { $0.dueAt <= referenceDate }
        guard !overdue.isEmpty else {
            return
        }

        logger.info("Reconciling \(overdue.count) overdue timer(s)")

        state.activeTimers.removeAll { $0.dueAt <= referenceDate }
        let finishedTimers = overdue.map { $0.finishedVersion() }
        state.recentTimers.insert(contentsOf: finishedTimers.reversed(), at: 0)
        trimRecentHistory()
        persistState()
        onTimersFinished?(finishedTimers)
    }

    private func persistState() {
        sortState()
        store.saveState(state)
    }

    private func sortState() {
        state.activeTimers.sort { $0.dueAt < $1.dueAt }
        state.recentTimers.sort { $0.dueAt > $1.dueAt }
    }

    private func trimRecentHistory() {
        state.recentTimers = Array(state.recentTimers.prefix(max(0, state.preferences.recentHistoryCount)))
    }

    private func refreshScheduling() {
        dueTimer?.cancel()
        refreshTimer?.cancel()
        dueTimer = nil
        refreshTimer = nil

        guard !state.activeTimers.isEmpty else {
            return
        }

        let nextDue = state.activeTimers[0].dueAt
        let delay = max(0, nextDue.timeIntervalSince(now()))

        let dueTimer = DispatchSource.makeTimerSource(queue: .main)
        dueTimer.schedule(deadline: .now() + .milliseconds(Int(delay * 1000)))
        dueTimer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleDueTimerFire()
            }
        }
        dueTimer.resume()
        self.dueTimer = dueTimer

        let refreshTimer = DispatchSource.makeTimerSource(queue: .main)
        refreshTimer.schedule(deadline: .now(), repeating: .seconds(1))
        refreshTimer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.onTick?()
            }
        }
        refreshTimer.resume()
        self.refreshTimer = refreshTimer
    }

    private func handleDueTimerFire() {
        reconcile(referenceDate: now())
        refreshScheduling()
        onTick?()
        onStateChange?(state)
    }
}
