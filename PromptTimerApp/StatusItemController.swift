import AppKit
import Foundation
import PromptTimerCore

@MainActor
final class StatusItemController: NSObject {
    private let timerManager: TimerManager
    private let openQuickAdd: () -> Void
    private let openPreferences: () -> Void
    private let quitApp: () -> Void
    private var statusItem: NSStatusItem?
    private var flashTimer: DispatchSourceTimer?

    init(
        timerManager: TimerManager,
        openQuickAdd: @escaping () -> Void,
        openPreferences: @escaping () -> Void,
        quitApp: @escaping () -> Void
    ) {
        self.timerManager = timerManager
        self.openQuickAdd = openQuickAdd
        self.openPreferences = openPreferences
        self.quitApp = quitApp
    }

    func refresh(state: AppState) {
        let shouldShow = state.preferences.alwaysShowMenuBarItem || !state.activeTimers.isEmpty
        guard shouldShow else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
            return
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Prompt Timer")
            item.button?.imagePosition = .imageLeading
            statusItem = item
        }

        updateButtonTitle(state: state)
        statusItem?.menu = buildMenu(state: state)
    }

    func refreshTitle(state: AppState) {
        updateButtonTitle(state: state)
    }

    func revealMenu() {
        guard let statusItem else {
            openQuickAdd()
            return
        }

        refresh(state: timerManager.state)
        statusItem.button?.performClick(nil)
    }

    func flash() {
        guard statusItem?.button != nil else { return }
        flashTimer?.cancel()

        let normalImage = NSImage(systemSymbolName: "timer", accessibilityDescription: "Prompt Timer")
        let flashImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Timer done")

        var tick = 0
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(400))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, let button = self.statusItem?.button else {
                    self?.flashTimer?.cancel()
                    self?.flashTimer = nil
                    return
                }
                button.image = tick % 2 == 0 ? flashImage : normalImage
                tick += 1
                if tick >= 8 {
                    button.image = normalImage
                    self.flashTimer?.cancel()
                    self.flashTimer = nil
                }
            }
        }
        flashTimer = timer
        timer.resume()
    }

    // MARK: - Private

    private func updateButtonTitle(state: AppState) {
        guard let button = statusItem?.button else {
            return
        }

        if state.preferences.showNextTimerInMenuBar, let nextTimer = timerManager.nextDueTimer() {
            button.title = TimeFormatting.shortDuration(nextTimer.remainingSeconds())
        } else if !state.activeTimers.isEmpty {
            button.title = "\(state.activeTimers.count)"
        } else {
            button.title = ""
        }
    }

    private func buildMenu(state: AppState) -> NSMenu {
        let menu = NSMenu()

        let quickAdd = NSMenuItem(title: "Quick Add Timer...", action: #selector(showQuickAdd), keyEquivalent: "")
        quickAdd.target = self
        menu.addItem(quickAdd)

        if let nextTimer = timerManager.nextDueTimer() {
            let summary = NSMenuItem(
                title: "Next: \(TimeFormatting.timerName(label: nextTimer.label, durationSeconds: nextTimer.durationSeconds)) in \(TimeFormatting.shortDuration(nextTimer.remainingSeconds()))",
                action: nil,
                keyEquivalent: ""
            )
            summary.isEnabled = false
            menu.addItem(summary)
        } else if let recentTimer = state.recentTimers.first {
            let restartLast = NSMenuItem(
                title: "Restart \(TimeFormatting.timerName(label: recentTimer.label, durationSeconds: recentTimer.durationSeconds))",
                action: #selector(restartRecentTimer(_:)),
                keyEquivalent: ""
            )
            restartLast.target = self
            restartLast.representedObject = recentTimer.id
            menu.addItem(restartLast)
        }

        menu.addItem(.separator())

        let activeHeader = NSMenuItem(title: "Active Timers", action: nil, keyEquivalent: "")
        activeHeader.isEnabled = false
        menu.addItem(activeHeader)

        if state.activeTimers.isEmpty {
            let empty = NSMenuItem(title: "No active timers", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for timer in state.activeTimers {
                let label = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
                let remaining = TimeFormatting.shortDuration(timer.remainingSeconds())
                let item = NSMenuItem(
                    title: "\(label)  \(remaining)",
                    action: #selector(cancelSpecificTimer(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = timer.id
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let recentHeader = NSMenuItem(title: "Recent Completed", action: nil, keyEquivalent: "")
        recentHeader.isEnabled = false
        menu.addItem(recentHeader)

        if state.recentTimers.isEmpty {
            let empty = NSMenuItem(title: "No recent timers", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for timer in state.recentTimers.prefix(5) {
                let label = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
                let item = NSMenuItem(
                    title: "\(label)  \(TimeFormatting.shortDuration(timer.durationSeconds))",
                    action: #selector(restartRecentTimer(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = timer.id
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let cancelTitle = state.activeTimers.count > 1 ? "Cancel Next Timer" : "Cancel Current Timer"
        let cancelNext = NSMenuItem(title: cancelTitle, action: #selector(cancelNextTimer), keyEquivalent: "")
        cancelNext.target = self
        cancelNext.isEnabled = !state.activeTimers.isEmpty
        menu.addItem(cancelNext)

        let cancelAll = NSMenuItem(title: "Cancel All Timers", action: #selector(cancelAllTimers), keyEquivalent: "")
        cancelAll.target = self
        cancelAll.isEnabled = !state.activeTimers.isEmpty
        menu.addItem(cancelAll)

        menu.addItem(.separator())

        let preferences = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func showQuickAdd() {
        openQuickAdd()
    }

    @objc private func showPreferences() {
        openPreferences()
    }

    @objc private func cancelNextTimer() {
        guard let nextTimer = timerManager.nextDueTimer() else {
            return
        }
        _ = timerManager.cancelTimer(id: nextTimer.id)
    }

    @objc private func cancelAllTimers() {
        _ = timerManager.cancelAllTimers()
    }

    @objc private func cancelSpecificTimer(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        _ = timerManager.cancelTimer(id: id)
    }

    @objc private func restartRecentTimer(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        _ = timerManager.restartRecentTimer(id: id)
    }

    @objc private func quitApplication() {
        quitApp()
    }
}
