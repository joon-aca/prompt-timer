import AppKit
import Foundation
import PromptTimerCore
import UserNotifications

@MainActor
final class PreferencesController: NSWindowController {
    var onPreferencesChanged: ((Preferences) -> Void)?

    private let alwaysShowButton = NSButton(checkboxWithTitle: "Always show menu bar item", target: nil, action: nil)
    private let showNextButton = NSButton(checkboxWithTitle: "Show next timer in menu bar", target: nil, action: nil)
    private let playSoundButton = NSButton(checkboxWithTitle: "Play sound on completion", target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let historyField = NSTextField(string: "")
    private let historyStepper = NSStepper()
    private let shortcutButton = ShortcutRecorderButton()
    private let soundPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let soundPreviewButton = NSButton(title: "\u{25B6}", target: nil, action: nil)
    private let celebrationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let funEffectPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let availableSounds = NotificationManager.availableSounds
    private let cliInstallButton = NSButton(title: "Install CLI", target: nil, action: nil)
    private let cliStatusLabel = NSTextField(labelWithString: "")
    private let notificationStatusLabel = NSTextField(labelWithString: "")

    var preferences = Preferences() {
        didSet {
            reload()
        }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 424),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Prompt Timer Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(notificationStatus: UNAuthorizationStatus) {
        updateNotificationStatus(notificationStatus)
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateNotificationStatus(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional:
            notificationStatusLabel.stringValue = "Notifications: enabled"
        case .denied:
            notificationStatusLabel.stringValue = "Notifications: enable in System Settings → Notifications"
        case .notDetermined:
            notificationStatusLabel.stringValue = "Notifications: will be requested on first timer"
        @unknown default:
            notificationStatusLabel.stringValue = "Notifications: unknown status"
        }
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        alwaysShowButton.target = self
        alwaysShowButton.action = #selector(preferenceChanged)
        showNextButton.target = self
        showNextButton.action = #selector(preferenceChanged)
        playSoundButton.target = self
        playSoundButton.action = #selector(preferenceChanged)
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(preferenceChanged)

        historyField.isEditable = false
        historyField.isBordered = true
        historyField.alignment = .center
        historyField.setAccessibilityLabel("Recent history count")

        historyStepper.minValue = 0
        historyStepper.maxValue = 50
        historyStepper.target = self
        historyStepper.action = #selector(historyStepperChanged)

        let historyLabel = NSTextField(labelWithString: "Recent history count")
        let historyRow = NSStackView(views: [historyLabel, historyField, historyStepper])
        historyRow.orientation = .horizontal
        historyRow.alignment = .centerY
        historyRow.spacing = 8

        let shortcutLabel = NSTextField(labelWithString: "Quick Add shortcut")
        shortcutButton.onShortcutRecorded = { [weak self] keyCode, modifiers in
            guard let self else { return }
            self.preferences.hotkeyKeyCode = keyCode
            self.preferences.hotkeyModifiers = modifiers
            self.onPreferencesChanged?(self.preferences)
        }
        let shortcutRow = NSStackView(views: [shortcutLabel, shortcutButton])
        shortcutRow.orientation = .horizontal
        shortcutRow.alignment = .centerY
        shortcutRow.spacing = 8

        let soundLabel = NSTextField(labelWithString: "Completion sound")
        soundPopup.removeAllItems()
        soundPopup.addItems(withTitles: availableSounds)
        soundPopup.target = self
        soundPopup.action = #selector(soundChanged)
        soundPreviewButton.bezelStyle = .rounded
        soundPreviewButton.target = self
        soundPreviewButton.action = #selector(previewSound)
        let soundRow = NSStackView(views: [soundLabel, soundPopup, soundPreviewButton])
        soundRow.orientation = .horizontal
        soundRow.alignment = .centerY
        soundRow.spacing = 8

        let celebrationLabel = NSTextField(labelWithString: "Completion celebration")
        celebrationPopup.removeAllItems()
        celebrationPopup.addItems(withTitles: CompletionCelebrationStyle.allCases.map(\.displayName))
        celebrationPopup.target = self
        celebrationPopup.action = #selector(celebrationStyleChanged)
        let celebrationRow = NSStackView(views: [celebrationLabel, celebrationPopup])
        celebrationRow.orientation = .horizontal
        celebrationRow.alignment = .centerY
        celebrationRow.spacing = 8

        let funEffectLabel = NSTextField(labelWithString: "Fun effect")
        funEffectPopup.removeAllItems()
        funEffectPopup.addItems(withTitles: FunCelebrationEffect.allCases.map(\.displayName))
        funEffectPopup.target = self
        funEffectPopup.action = #selector(funEffectChanged)
        let funEffectRow = NSStackView(views: [funEffectLabel, funEffectPopup])
        funEffectRow.orientation = .horizontal
        funEffectRow.alignment = .centerY
        funEffectRow.spacing = 8

        cliInstallButton.bezelStyle = .rounded
        cliInstallButton.target = self
        cliInstallButton.action = #selector(installCLI)
        cliStatusLabel.font = .systemFont(ofSize: 11)
        cliStatusLabel.textColor = .secondaryLabelColor
        cliStatusLabel.lineBreakMode = .byTruncatingMiddle
        let cliRow = NSStackView(views: [cliInstallButton, cliStatusLabel])
        cliRow.orientation = .horizontal
        cliRow.alignment = .centerY
        cliRow.spacing = 8

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(alwaysShowButton)
        stack.addArrangedSubview(showNextButton)
        stack.addArrangedSubview(playSoundButton)
        stack.addArrangedSubview(soundRow)
        stack.addArrangedSubview(celebrationRow)
        stack.addArrangedSubview(funEffectRow)
        stack.addArrangedSubview(launchAtLoginButton)
        stack.addArrangedSubview(historyRow)
        stack.addArrangedSubview(shortcutRow)
        stack.addArrangedSubview(cliRow)
        stack.addArrangedSubview(notificationStatusLabel)

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
        ])
    }

    private func reload() {
        alwaysShowButton.state = preferences.alwaysShowMenuBarItem ? .on : .off
        showNextButton.state = preferences.showNextTimerInMenuBar ? .on : .off
        playSoundButton.state = preferences.playSoundOnCompletion ? .on : .off
        launchAtLoginButton.state = preferences.launchAtLogin ? .on : .off
        historyStepper.integerValue = preferences.recentHistoryCount
        historyField.stringValue = "\(preferences.recentHistoryCount)"
        shortcutButton.display(keyCode: preferences.hotkeyKeyCode, modifiers: preferences.hotkeyModifiers)
        if let index = availableSounds.firstIndex(of: preferences.completionSound) {
            soundPopup.selectItem(at: index)
        }
        if let index = CompletionCelebrationStyle.allCases.firstIndex(of: preferences.completionCelebrationStyle) {
            celebrationPopup.selectItem(at: index)
        }
        if let index = FunCelebrationEffect.allCases.firstIndex(of: preferences.funCelebrationEffect) {
            funEffectPopup.selectItem(at: index)
        }
        funEffectPopup.isEnabled = preferences.completionCelebrationStyle == .fun
        refreshCLIStatus()
    }

    private func refreshCLIStatus() {
        if CLIInstaller.isInstalled {
            cliInstallButton.title = "Uninstall CLI"
            cliStatusLabel.stringValue = "Installed at \(CLIInstaller.linkPath)"
        } else {
            cliInstallButton.title = "Install CLI"
            cliStatusLabel.stringValue = "Use 'timer' from any terminal"
        }
    }

    @objc private func soundChanged() {
        guard let title = soundPopup.selectedItem?.title else { return }
        preferences.completionSound = title
        onPreferencesChanged?(preferences)
        NotificationManager.playSound(named: title)
    }

    @objc private func previewSound() {
        guard let title = soundPopup.selectedItem?.title else { return }
        NotificationManager.playSound(named: title)
    }

    @objc private func celebrationStyleChanged() {
        let selectedIndex = celebrationPopup.indexOfSelectedItem
        guard CompletionCelebrationStyle.allCases.indices.contains(selectedIndex) else {
            return
        }
        preferences.completionCelebrationStyle = CompletionCelebrationStyle.allCases[selectedIndex]
        funEffectPopup.isEnabled = preferences.completionCelebrationStyle == .fun
        onPreferencesChanged?(preferences)
    }

    @objc private func funEffectChanged() {
        let selectedIndex = funEffectPopup.indexOfSelectedItem
        guard FunCelebrationEffect.allCases.indices.contains(selectedIndex) else {
            return
        }
        preferences.funCelebrationEffect = FunCelebrationEffect.allCases[selectedIndex]
        onPreferencesChanged?(preferences)
    }

    @objc private func installCLI() {
        let message: String
        if CLIInstaller.isInstalled {
            message = CLIInstaller.uninstall()
        } else {
            message = CLIInstaller.install()
        }
        cliStatusLabel.stringValue = message
        refreshCLIStatus()
    }

    @objc private func preferenceChanged() {
        preferences.alwaysShowMenuBarItem = alwaysShowButton.state == .on
        preferences.showNextTimerInMenuBar = showNextButton.state == .on
        preferences.playSoundOnCompletion = playSoundButton.state == .on
        preferences.launchAtLogin = launchAtLoginButton.state == .on
        onPreferencesChanged?(preferences)
    }

    @objc private func historyStepperChanged() {
        preferences.recentHistoryCount = historyStepper.integerValue
        historyField.stringValue = "\(preferences.recentHistoryCount)"
        onPreferencesChanged?(preferences)
    }
}
