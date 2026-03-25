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

    func revealMenu() {
        guard let statusItem else {
            openQuickAdd()
            return
        }

        refresh(state: timerManager.state)
        statusItem.button?.performClick(nil)
    }

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

        menu.addItem(.separator())

        let activeHeader = NSMenuItem(title: "Active Timers", action: nil, keyEquivalent: "")
        activeHeader.isEnabled = false
        menu.addItem(activeHeader)

        if state.activeTimers.isEmpty {
            let empty = NSMenuItem(title: "No active timers", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for timer in timerManager.listActiveTimers() {
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
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let cancelTitle = switch state.activeTimers.count {
        case 0:
            "Cancel Current Timer"
        case 1:
            "Cancel Current Timer"
        default:
            "Cancel Soonest Timer"
        }
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

    @objc private func quitApplication() {
        quitApp()
    }
}
