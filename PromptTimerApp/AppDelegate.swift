import AppKit
import Foundation
import PromptTimerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = PromptTimerLogger(category: "AppDelegate")
    private var timerStore: TimerStore?
    private var timerManager: TimerManager?
    private var statusItemController: StatusItemController?
    private var notificationManager: NotificationManager?
    private var completionOverlayController: CompletionOverlayController?
    private var quickAddWindowController: QuickAddWindowController?
    private var preferencesController: PreferencesController?
    private var ipcServer: IPCServer?
    private var wakeMonitor: WakeMonitor?
    private var hotkeyManager: HotkeyManager?
    private let launchManager = LaunchManager()
    private var lastLaunchAtLogin: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            logger.debug("Application did finish launching")
            let timerStore = try TimerStore()
            let timerManager = TimerManager(store: timerStore)
            let notificationManager = NotificationManager()
            let wakeMonitor = WakeMonitor()
            let completionOverlayController = CompletionOverlayController()

            let statusItemController = StatusItemController(
                timerManager: timerManager,
                openQuickAdd: { [weak self] in self?.presentQuickAdd() },
                openPreferences: { [weak self] in self?.presentPreferences() },
                quitApp: {
                    NSApp.terminate(nil)
                }
            )

            timerManager.onStateChange = { [weak self] state in
                self?.statusItemController?.refresh(state: state)
                self?.preferencesController?.preferences = state.preferences
                if state.preferences.launchAtLogin != self?.lastLaunchAtLogin {
                    self?.lastLaunchAtLogin = state.preferences.launchAtLogin
                    self?.launchManager.applyPreference(state.preferences.launchAtLogin)
                }
                self?.hotkeyManager?.register(
                    keyCode: state.preferences.hotkeyKeyCode,
                    modifiers: state.preferences.hotkeyModifiers
                )
            }

            timerManager.onTimersFinished = { [weak self] timers in
                guard let self, let notificationManager = self.notificationManager else {
                    return
                }
                let prefs = self.timerManager?.state.preferences ?? Preferences()
                for timer in timers {
                    notificationManager.sendCompletionNotification(
                        for: timer, playSound: prefs.playSoundOnCompletion, soundName: prefs.completionSound
                    )
                }
                self.completionOverlayController?.present(
                    for: timers,
                    style: prefs.completionCelebrationStyle,
                    funEffect: prefs.funCelebrationEffect
                )
                self.statusItemController?.flash()
            }

            timerManager.onTick = { [weak self] in
                guard let self, let manager = self.timerManager else {
                    return
                }
                self.statusItemController?.refreshTitle(state: manager.state)
            }

            wakeMonitor.onWake = { [weak timerManager] in
                timerManager?.handleWake()
            }

            let ipcServer = IPCServer(
                socketPath: timerStore.socketPath
            ) { [weak self] command in
                guard let self else {
                    return IPCResponse.failure("Prompt Timer is shutting down.")
                }
                return await MainActor.run {
                    self.handle(command)
                }
            }

            self.timerStore = timerStore
            self.timerManager = timerManager
            self.statusItemController = statusItemController
            self.notificationManager = notificationManager
            self.completionOverlayController = completionOverlayController
            self.wakeMonitor = wakeMonitor
            self.ipcServer = ipcServer

            let hotkeyManager = HotkeyManager { [weak self] in
                self?.presentQuickAdd()
            }
            self.hotkeyManager = hotkeyManager

            notificationManager.refreshAuthorizationStatus()
            wakeMonitor.start()
            try ipcServer.start()
            logger.debug("IPC server started on \(timerStore.socketPath)")
            timerManager.load()
            statusItemController.refresh(state: timerManager.state)
        } catch {
            NSLog("Prompt Timer failed to start: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        wakeMonitor?.stop()
        ipcServer?.stop()
    }

    private func handle(_ command: IPCCommand) -> IPCResponse {
        logger.debug("Handling IPC command \(command.command.rawValue)")
        guard let timerManager, let notificationManager else {
            return .failure("Prompt Timer is unavailable.")
        }

        switch command.command {
        case .start:
            guard let durationSeconds = command.durationSeconds, durationSeconds > 0 else {
                return .failure("Invalid duration. Use 10, 25m, 30s, or 1h30m")
            }

            notificationManager.requestAuthorizationIfNeeded()
            let timer = timerManager.startTimer(durationSeconds: durationSeconds, label: command.label)
            let message = OutputMessages.started(timer: timer)
            return .success(message, timers: timerManager.snapshots())

        case .list:
            let timers = timerManager.snapshots()
            if timers.isEmpty {
                return .success("No active timers")
            }
            return .success("\(timers.count) active timer(s)", timers: timers)

        case .status:
            return .success(timerManager.statusMessage(), timers: timerManager.snapshots())

        case .cancel:
            if let id = command.id {
                guard let timer = timerManager.cancelTimer(id: id) else {
                    return .failure("No timer found with id \(id)")
                }
                let label = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
                return .success("Cancelled \(label)", timers: timerManager.snapshots())
            }

            guard let timer = timerManager.cancelOnlyTimerIfPossible() else {
                return .failure("Multiple timers are active. Use `timer cancel <id>` or `timer cancel all`.")
            }
            let label = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
            return .success("Cancelled \(label)", timers: timerManager.snapshots())

        case .cancelAll:
            let count = timerManager.cancelAllTimers()
            return .success("Cancelled \(count) timer(s)")

        case .test:
            notificationManager.requestAuthorizationIfNeeded()
            notificationManager.sendTestNotification(
                playSound: timerManager.state.preferences.playSoundOnCompletion,
                soundName: timerManager.state.preferences.completionSound
            )
            return .success("Sent test notification")

        case .open:
            if timerManager.state.activeTimers.isEmpty {
                presentQuickAdd()
            } else {
                statusItemController?.revealMenu()
            }
            return .success("Opened Prompt Timer")
        }
    }

    private func presentQuickAdd() {
        guard let timerManager, let notificationManager else {
            return
        }

        if quickAddWindowController == nil {
            let controller = QuickAddWindowController()
            controller.onStart = { rawInput in
                let tokens = rawInput.split(whereSeparator: \.isWhitespace).map(String.init)
                let (seconds, remaining) = try DurationParser.parseTokens(tokens)
                let label = remaining.joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                notificationManager.requestAuthorizationIfNeeded()
                _ = timerManager.startTimer(
                    durationSeconds: seconds,
                    label: label.isEmpty ? nil : label
                )
            }
            quickAddWindowController = controller
        }

        quickAddWindowController?.present()
    }

    private func presentPreferences() {
        guard let timerManager, let notificationManager else {
            return
        }

        if preferencesController == nil {
            let controller = PreferencesController()
            controller.onPreferencesChanged = { [weak self] preferences in
                self?.timerManager?.updatePreferences { current in
                    current = preferences
                }
            }
            preferencesController = controller
        }

        preferencesController?.preferences = timerManager.state.preferences
        preferencesController?.present(notificationStatus: notificationManager.authorizationStatus)
    }
}

private enum OutputMessages {
    static func started(timer: TimerEntry) -> String {
        var message = "Started timer for \(TimeFormatting.shortDuration(timer.durationSeconds))"
        if let label = timer.label {
            message += " - \(label)"
        }
        return message
    }
}
