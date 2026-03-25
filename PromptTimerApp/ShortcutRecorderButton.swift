import AppKit
import Carbon

@MainActor
final class ShortcutRecorderButton: NSButton {
    var onShortcutRecorded: ((UInt32, UInt32) -> Void)?

    private var isRecording = false
    private var localMonitor: Any?

    private(set) var currentKeyCode: UInt32 = 0
    private(set) var currentModifiers: UInt32 = 0

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(keyCode: UInt32, modifiers: UInt32) {
        currentKeyCode = keyCode
        currentModifiers = modifiers
        title = HotkeyDisplay.string(keyCode: keyCode, modifiers: modifiers)
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        title = "Press shortcut..."

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels recording
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }

            // Require at least one modifier (Cmd, Ctrl, or Option)
            let hasModifier = modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option)
            guard hasModifier else { return nil }

            let carbonMods = HotkeyDisplay.carbonModifiers(from: modifiers)
            let keyCode = UInt32(event.keyCode)

            self.currentKeyCode = keyCode
            self.currentModifiers = carbonMods
            self.title = HotkeyDisplay.string(keyCode: keyCode, modifiers: carbonMods)
            self.stopRecording()
            self.onShortcutRecorded?(keyCode, carbonMods)

            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if title == "Press shortcut..." {
            display(keyCode: currentKeyCode, modifiers: currentModifiers)
        }
    }
}
