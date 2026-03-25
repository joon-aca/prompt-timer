import AppKit
import Foundation
import PromptTimerCore

@MainActor
final class QuickAddWindowController: NSWindowController, NSTextFieldDelegate {
    var onStart: ((String) throws -> Void)?

    private let inputField = NSTextField(string: "")
    private let errorLabel = NSTextField(labelWithString: "")

    init() {
        let panelWidth: CGFloat = 560
        let panelHeight: CGFloat = 58

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        super.init(window: panel)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        inputField.stringValue = ""
        errorLabel.stringValue = ""
        errorLabel.isHidden = true
        resizePanel(showingError: false)
        positionNearTopOfScreen()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(inputField)
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submitInput()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            close()
            return true
        }
        return false
    }

    // MARK: - Private

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let vibrancy = NSVisualEffectView()
        vibrancy.translatesAutoresizingMaskIntoConstraints = false
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.blendingMode = .behindWindow
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = 12
        vibrancy.layer?.masksToBounds = true
        contentView.addSubview(vibrancy)

        NSLayoutConstraint.activate([
            vibrancy.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            vibrancy.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            vibrancy.topAnchor.constraint(equalTo: contentView.topAnchor),
            vibrancy.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer")
        icon.contentTintColor = .tertiaryLabelColor
        icon.setContentHuggingPriority(.required, for: .horizontal)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholderString = "25 deep work"
        inputField.setAccessibilityLabel("Timer input")
        inputField.font = .systemFont(ofSize: 24, weight: .light)
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.delegate = self

        let inputRow = NSStackView(views: [icon, inputField])
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        inputRow.orientation = .horizontal
        inputRow.spacing = 10
        inputRow.alignment = .centerY
        inputRow.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.lineBreakMode = .byTruncatingTail
        errorLabel.isHidden = true

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 0
        stack.addArrangedSubview(inputRow)
        stack.addArrangedSubview(separator)
        stack.addArrangedSubview(errorLabel)
        stack.setCustomSpacing(8, after: separator)

        vibrancy.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            inputRow.heightAnchor.constraint(equalToConstant: 48),
            stack.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor),
            stack.topAnchor.constraint(equalTo: vibrancy.topAnchor),
            stack.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor, constant: -8),
            errorLabel.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor, constant: 50),
            errorLabel.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor, constant: -16),
        ])
    }

    private func submitInput() {
        do {
            try onStart?(inputField.stringValue)
            inputField.stringValue = ""
            errorLabel.stringValue = ""
            errorLabel.isHidden = true
            resizePanel(showingError: false)
            close()
        } catch {
            errorLabel.stringValue = error.localizedDescription
            errorLabel.isHidden = false
            resizePanel(showingError: true)
        }
    }

    private func positionNearTopOfScreen() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - screenFrame.height * 0.28
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func resizePanel(showingError: Bool) {
        guard let panel = window else { return }
        let height: CGFloat = showingError ? 82 : 58
        var frame = panel.frame
        let delta = height - frame.height
        frame.size.height = height
        frame.origin.y -= delta
        panel.setFrame(frame, display: true, animate: true)
    }
}
