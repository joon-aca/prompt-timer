import AppKit
import Foundation
import PromptTimerCore
import QuartzCore

@MainActor
final class CompletionOverlayController {
    private let classicPanel: NSPanel
    private let classicEffectView = NSVisualEffectView()
    private let classicIconView = NSImageView()
    private let classicTitleLabel = NSTextField(labelWithString: "")
    private let classicSubtitleLabel = NSTextField(labelWithString: "")

    private var funWindow: NSWindow?
    private let funRootView = NSView()
    private let funTintLayer = CAGradientLayer()
    private let confettiLayer = CAEmitterLayer()
    private let lightningGlowLayer = CAShapeLayer()
    private let lightningLayer = CAShapeLayer()
    private var fireworkLayers: [CAEmitterLayer] = []
    private var balloonContainers: [CALayer] = []
    private let funTextContainer = NSView()
    private let funTitleLabel = NSTextField(labelWithString: "")
    private let funSubtitleLabel = NSTextField(labelWithString: "")

    private var dismissWorkItem: DispatchWorkItem?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 148),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .alertPanel
        classicPanel = panel

        buildClassicUI()
    }

    func present(
        for timers: [TimerEntry],
        style: CompletionCelebrationStyle,
        funEffect: FunCelebrationEffect
    ) {
        guard !timers.isEmpty else {
            return
        }

        dismissWorkItem?.cancel()
        classicPanel.orderOut(nil)
        funWindow?.orderOut(nil)
        resetFunLayers()

        switch style {
        case .classic:
            presentClassic(for: timers)
        case .fun:
            presentFun(for: timers, on: targetScreen(), effect: resolvedFunEffect(funEffect))
        }
    }

    private func buildClassicUI() {
        guard let contentView = classicPanel.contentView else {
            return
        }

        classicEffectView.translatesAutoresizingMaskIntoConstraints = false
        classicEffectView.material = .hudWindow
        classicEffectView.state = .active
        classicEffectView.blendingMode = .behindWindow
        classicEffectView.wantsLayer = true
        classicEffectView.layer?.cornerRadius = 22
        classicEffectView.layer?.masksToBounds = true
        classicEffectView.layer?.borderWidth = 1
        classicEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        contentView.addSubview(classicEffectView)

        classicIconView.translatesAutoresizingMaskIntoConstraints = false
        classicIconView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Timer complete")
        classicIconView.contentTintColor = .systemOrange
        classicIconView.symbolConfiguration = .init(pointSize: 26, weight: .semibold)

        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 28
        iconContainer.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.18).cgColor
        iconContainer.addSubview(classicIconView)

        classicTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        classicTitleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        classicTitleLabel.textColor = .labelColor
        classicTitleLabel.lineBreakMode = .byTruncatingTail
        classicTitleLabel.maximumNumberOfLines = 1

        classicSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        classicSubtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        classicSubtitleLabel.textColor = .secondaryLabelColor
        classicSubtitleLabel.lineBreakMode = .byTruncatingTail
        classicSubtitleLabel.maximumNumberOfLines = 1

        let textStack = NSStackView(views: [classicTitleLabel, classicSubtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let row = NSStackView(views: [iconContainer, textStack])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 16
        classicEffectView.addSubview(row)

        NSLayoutConstraint.activate([
            classicEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            classicEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            classicEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            classicEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            classicIconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            classicIconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),

            row.leadingAnchor.constraint(equalTo: classicEffectView.leadingAnchor, constant: 26),
            row.trailingAnchor.constraint(equalTo: classicEffectView.trailingAnchor, constant: -26),
            row.topAnchor.constraint(equalTo: classicEffectView.topAnchor, constant: 22),
            row.bottomAnchor.constraint(equalTo: classicEffectView.bottomAnchor, constant: -22),
        ])
    }

    private func presentClassic(for timers: [TimerEntry]) {
        updateClassicCopy(for: timers)
        positionClassicPanel(on: targetScreen())

        classicPanel.alphaValue = 0
        classicPanel.orderFrontRegardless()

        guard let contentView = classicPanel.contentView else {
            return
        }

        contentView.wantsLayer = true
        contentView.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            classicPanel.animator().alphaValue = 1
            contentView.animator().layer?.transform = CATransform3DIdentity
        }

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismissClassic()
        }
        self.dismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismissWorkItem)
    }

    private func updateClassicCopy(for timers: [TimerEntry]) {
        if timers.count == 1, let timer = timers.first {
            classicTitleLabel.stringValue = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
            classicSubtitleLabel.stringValue = "Finished"
            return
        }

        classicTitleLabel.stringValue = "\(timers.count) timers finished"
        let names = timers
            .prefix(2)
            .map { TimeFormatting.timerName(label: $0.label, durationSeconds: $0.durationSeconds) }
        let remainder = timers.count - names.count
        classicSubtitleLabel.stringValue = remainder > 0
            ? names.joined(separator: " • ") + " • +\(remainder) more"
            : names.joined(separator: " • ")
    }

    private func dismissClassic() {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                classicPanel.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                self?.classicPanel.orderOut(nil)
            }
        )
    }

    private func ensureFunWindow(on screen: NSScreen?) {
        let frame = screen?.frame ?? NSScreen.main?.frame ?? .zero

        if funWindow == nil {
            let window = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .stationary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false

            funRootView.frame = frame
            funRootView.wantsLayer = true
            window.contentView = funRootView

            buildFunScene()
            funWindow = window
        }

        funWindow?.setFrame(frame, display: true)
        funRootView.frame = frame
        layoutFunScene()
    }

    private func buildFunScene() {
        guard let rootLayer = funRootView.layer else {
            return
        }

        buildFunTextUI()

        funTintLayer.colors = [
            NSColor.systemPink.withAlphaComponent(0.14).cgColor,
            NSColor.systemOrange.withAlphaComponent(0.1).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.08).cgColor,
        ]
        funTintLayer.startPoint = CGPoint(x: 0, y: 1)
        funTintLayer.endPoint = CGPoint(x: 1, y: 0)
        funTintLayer.opacity = 0
        rootLayer.addSublayer(funTintLayer)

        confettiLayer.emitterShape = .line
        confettiLayer.emitterMode = .outline
        confettiLayer.birthRate = 0
        confettiLayer.opacity = 0
        rootLayer.addSublayer(confettiLayer)

        lightningGlowLayer.fillColor = NSColor.clear.cgColor
        lightningGlowLayer.strokeColor = NSColor.systemYellow.withAlphaComponent(0.45).cgColor
        lightningGlowLayer.lineWidth = 26
        lightningGlowLayer.lineJoin = .round
        lightningGlowLayer.lineCap = .round
        lightningGlowLayer.shadowColor = NSColor.systemBlue.cgColor
        lightningGlowLayer.shadowOpacity = 0.8
        lightningGlowLayer.shadowRadius = 28
        lightningGlowLayer.opacity = 0
        rootLayer.addSublayer(lightningGlowLayer)

        lightningLayer.fillColor = NSColor.clear.cgColor
        lightningLayer.strokeColor = NSColor.white.cgColor
        lightningLayer.lineWidth = 11
        lightningLayer.lineJoin = .round
        lightningLayer.lineCap = .round
        lightningLayer.opacity = 0
        rootLayer.addSublayer(lightningLayer)

        fireworkLayers = (0..<6).map { _ in
            let layer = CAEmitterLayer()
            layer.emitterShape = .point
            layer.emitterMode = .points
            layer.renderMode = .additive
            layer.birthRate = 0
            layer.opacity = 0
            rootLayer.addSublayer(layer)
            return layer
        }

        balloonContainers = (0..<14).map { index in
            let container = CALayer()
            container.bounds = CGRect(x: 0, y: 0, width: 64, height: 140)
            container.opacity = 0

            let stringLayer = CAShapeLayer()
            stringLayer.frame = container.bounds
            let stringPath = CGMutablePath()
            stringPath.move(to: CGPoint(x: 32, y: 4))
            stringPath.addCurve(
                to: CGPoint(x: 32, y: 74),
                control1: CGPoint(x: 28, y: 24),
                control2: CGPoint(x: 36, y: 50)
            )
            stringLayer.path = stringPath
            stringLayer.strokeColor = NSColor.white.withAlphaComponent(0.7).cgColor
            stringLayer.lineWidth = 2
            stringLayer.fillColor = NSColor.clear.cgColor

            let balloonLayer = CAShapeLayer()
            balloonLayer.frame = container.bounds
            balloonLayer.path = CGPath(ellipseIn: CGRect(x: 10, y: 70, width: 44, height: 56), transform: nil)
            balloonLayer.fillColor = balloonColor(at: index).cgColor
            balloonLayer.shadowColor = NSColor.black.cgColor
            balloonLayer.shadowOpacity = 0.2
            balloonLayer.shadowRadius = 8
            balloonLayer.shadowOffset = CGSize(width: 0, height: -2)

            let knotLayer = CAShapeLayer()
            knotLayer.frame = container.bounds
            let knotPath = CGMutablePath()
            knotPath.move(to: CGPoint(x: 27, y: 74))
            knotPath.addLine(to: CGPoint(x: 37, y: 74))
            knotPath.addLine(to: CGPoint(x: 32, y: 66))
            knotPath.closeSubpath()
            knotLayer.path = knotPath
            knotLayer.fillColor = balloonColor(at: index).darker(amount: 0.16).cgColor

            container.addSublayer(stringLayer)
            container.addSublayer(balloonLayer)
            container.addSublayer(knotLayer)
            rootLayer.addSublayer(container)
            return container
        }
    }

    private func layoutFunScene() {
        guard let rootLayer = funRootView.layer else {
            return
        }

        funTintLayer.frame = rootLayer.bounds
        confettiLayer.frame = rootLayer.bounds
        confettiLayer.emitterPosition = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.maxY - 8)
        confettiLayer.emitterSize = CGSize(width: max(120, rootLayer.bounds.width - 80), height: 1)

        let burstPositions = [
            CGPoint(x: rootLayer.bounds.width * 0.14, y: rootLayer.bounds.height * 0.68),
            CGPoint(x: rootLayer.bounds.width * 0.28, y: rootLayer.bounds.height * 0.8),
            CGPoint(x: rootLayer.bounds.width * 0.42, y: rootLayer.bounds.height * 0.56),
            CGPoint(x: rootLayer.bounds.width * 0.6, y: rootLayer.bounds.height * 0.76),
            CGPoint(x: rootLayer.bounds.width * 0.74, y: rootLayer.bounds.height * 0.6),
            CGPoint(x: rootLayer.bounds.width * 0.86, y: rootLayer.bounds.height * 0.72),
        ]
        for (index, layer) in fireworkLayers.enumerated() {
            layer.frame = rootLayer.bounds
            layer.emitterPosition = burstPositions[index]
            layer.emitterSize = .zero
        }

        let lightningPath = CGMutablePath()
        let width = rootLayer.bounds.width
        let height = rootLayer.bounds.height
        lightningPath.move(to: CGPoint(x: width * 0.56, y: height * 0.88))
        lightningPath.addLine(to: CGPoint(x: width * 0.49, y: height * 0.63))
        lightningPath.addLine(to: CGPoint(x: width * 0.57, y: height * 0.63))
        lightningPath.addLine(to: CGPoint(x: width * 0.42, y: height * 0.28))
        lightningPath.addLine(to: CGPoint(x: width * 0.5, y: height * 0.5))
        lightningPath.addLine(to: CGPoint(x: width * 0.43, y: height * 0.5))
        lightningGlowLayer.path = lightningPath
        lightningLayer.path = lightningPath

        let titleFontSize = max(72, min(150, width * 0.1))
        let subtitleFontSize = max(22, min(42, width * 0.03))
        funTitleLabel.font = .systemFont(ofSize: titleFontSize, weight: .black)
        funSubtitleLabel.font = .systemFont(ofSize: subtitleFontSize, weight: .semibold)
    }

    private func presentFun(for timers: [TimerEntry], on screen: NSScreen?, effect: FunCelebrationEffect) {
        ensureFunWindow(on: screen)
        guard let window = funWindow else {
            return
        }

        window.alphaValue = 1
        window.orderFrontRegardless()

        switch effect {
        case .auto:
            presentFun(for: timers, on: screen, effect: resolvedFunEffect(.auto))
            return
        case .confetti:
            runConfettiAnimation()
        case .fireworks:
            runFireworksAnimation()
        case .lightning:
            runLightningAnimation()
        case .balloons:
            runBalloonsAnimation()
        case .glowText:
            runGlowTextAnimation(for: timers)
        }

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismissFun()
        }
        self.dismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: dismissWorkItem)
    }

    private func runConfettiAnimation() {
        funTintLayer.opacity = 0.35
        confettiLayer.opacity = 1
        confettiLayer.emitterCells = makeConfettiCells()
        confettiLayer.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { [weak self] in
            self?.confettiLayer.birthRate = 0
        }
    }

    private func runFireworksAnimation() {
        funTintLayer.opacity = 0.18
        let colors: [NSColor] = [.systemPink, .systemOrange, .systemYellow, .systemTeal, .systemBlue, .systemPurple]

        for (index, layer) in fireworkLayers.enumerated() {
            let delay = Double(index) * 0.18
            let color = colors[index % colors.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak layer] in
                guard let self, let layer else {
                    return
                }
                layer.opacity = 1
                layer.emitterCells = self.makeFireworkBurstCells(color: color)
                layer.birthRate = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.16) { [weak layer] in
                layer?.birthRate = 0
            }
        }
    }

    private func runLightningAnimation() {
        funTintLayer.opacity = 0.26
        lightningGlowLayer.opacity = 1
        lightningLayer.opacity = 1

        let flash = CABasicAnimation(keyPath: "opacity")
        flash.fromValue = 0.55
        flash.toValue = 0
        flash.duration = 0.25
        flash.autoreverses = true
        flash.repeatCount = 2
        funTintLayer.add(flash, forKey: "lightning.flash")

        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = 0
        stroke.toValue = 1
        stroke.duration = 0.16
        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lightningGlowLayer.add(stroke, forKey: "lightning.stroke")
        lightningLayer.add(stroke, forKey: "lightning.stroke")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0.35, 1, 0]
        opacity.keyTimes = [0, 0.18, 0.44, 0.62, 1]
        opacity.duration = 0.8
        lightningGlowLayer.add(opacity, forKey: "lightning.opacity")
        lightningLayer.add(opacity, forKey: "lightning.opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.lightningGlowLayer.opacity = 0
            self?.lightningLayer.opacity = 0
            self?.funTintLayer.opacity = 0
        }
    }

    private func runBalloonsAnimation() {
        funTintLayer.opacity = 0.18
        guard let rootLayer = funRootView.layer else {
            return
        }

        let width = rootLayer.bounds.width
        let height = rootLayer.bounds.height
        var rng = SystemRandomNumberGenerator()
        let now = CACurrentMediaTime()

        for container in balloonContainers {
            let startX = CGFloat.random(in: 0.04...0.96, using: &rng) * width
            let start = CGPoint(
                x: startX,
                y: CGFloat.random(in: -360 ... -120, using: &rng)
            )
            let end = CGPoint(
                x: startX + CGFloat.random(in: -180 ... 180, using: &rng),
                y: height + CGFloat.random(in: 140 ... 300, using: &rng)
            )
            let control1 = CGPoint(
                x: start.x + CGFloat.random(in: -160 ... 160, using: &rng),
                y: height * CGFloat.random(in: 0.16 ... 0.36, using: &rng)
            )
            let control2 = CGPoint(
                x: start.x + CGFloat.random(in: -220 ... 220, using: &rng),
                y: height * CGFloat.random(in: 0.56 ... 0.92, using: &rng)
            )

            let path = CGMutablePath()
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)

            let move = CAKeyframeAnimation(keyPath: "position")
            move.path = path
            move.duration = Double(CGFloat.random(in: 2.8 ... 4.6, using: &rng))
            move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 1, 1, 0]
            opacity.keyTimes = [0, 0.1, 0.86, 1]
            opacity.duration = move.duration

            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = CGFloat.random(in: -0.16 ... -0.04, using: &rng)
            rotation.toValue = CGFloat.random(in: 0.04 ... 0.16, using: &rng)
            rotation.duration = Double(CGFloat.random(in: 0.7 ... 1.2, using: &rng))
            rotation.autoreverses = true
            rotation.repeatCount = Float.random(in: 3.5 ... 6.5, using: &rng)

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            let baseScale = CGFloat.random(in: 0.78 ... 1.26, using: &rng)
            scale.values = [baseScale * 0.92, baseScale, baseScale * 1.04, baseScale]
            scale.keyTimes = [0, 0.18, 0.6, 1]
            scale.duration = move.duration

            let group = CAAnimationGroup()
            group.animations = [move, opacity, rotation, scale]
            group.duration = move.duration
            group.beginTime = now + Double(CGFloat.random(in: 0 ... 0.9, using: &rng))
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            container.add(group, forKey: "balloon.\(UUID().uuidString)")
        }
    }

    private func runGlowTextAnimation(for timers: [TimerEntry]) {
        let copy = funMessageCopy(for: timers)
        funTitleLabel.stringValue = copy.title
        funSubtitleLabel.stringValue = copy.subtitle

        funTintLayer.colors = [
            NSColor.systemOrange.withAlphaComponent(0.42).cgColor,
            NSColor.systemPink.withAlphaComponent(0.3).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.18).cgColor,
        ]
        funTintLayer.opacity = 0.5

        funTextContainer.isHidden = false
        funTextContainer.alphaValue = 1
        funTextContainer.layer?.opacity = 1
        funTextContainer.layer?.transform = CATransform3DIdentity
        funTitleLabel.layer?.opacity = 1
        funSubtitleLabel.layer?.opacity = 1

        let entrance = CAAnimationGroup()
        let scaleIn = CABasicAnimation(keyPath: "transform.scale")
        scaleIn.fromValue = 0.78
        scaleIn.toValue = 1

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1

        entrance.animations = [scaleIn, fadeIn]
        entrance.duration = 0.28
        entrance.timingFunction = CAMediaTimingFunction(name: .easeOut)
        funTextContainer.layer?.add(entrance, forKey: "glowText.entrance")

        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1, 1.04, 0.995, 1.03, 1]
        pulse.keyTimes = [0, 0.22, 0.46, 0.72, 1]
        pulse.duration = 1.5
        pulse.beginTime = CACurrentMediaTime() + 0.2
        pulse.repeatCount = 1.5
        pulse.isRemovedOnCompletion = true
        funTextContainer.layer?.add(pulse, forKey: "glowText.pulse")

        let glow = CAKeyframeAnimation(keyPath: "shadowRadius")
        glow.values = [28, 46, 32, 52, 30]
        glow.keyTimes = [0, 0.25, 0.5, 0.76, 1]
        glow.duration = 1.3
        glow.beginTime = CACurrentMediaTime() + 0.1
        glow.repeatCount = 2
        glow.isRemovedOnCompletion = true
        funTitleLabel.layer?.add(glow, forKey: "glowText.shadowRadius")
    }

    private func dismissFun() {
        guard let window = funWindow else {
            return
        }

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                self?.resetFunLayers()
                window.orderOut(nil)
                window.alphaValue = 1
            }
        )
    }

    private func resetFunLayers() {
        confettiLayer.birthRate = 0
        confettiLayer.emitterCells = nil
        confettiLayer.removeAllAnimations()
        confettiLayer.opacity = 0

        funTintLayer.removeAllAnimations()
        funTintLayer.opacity = 0

        lightningGlowLayer.removeAllAnimations()
        lightningGlowLayer.opacity = 0
        lightningLayer.removeAllAnimations()
        lightningLayer.opacity = 0

        fireworkLayers.forEach {
            $0.removeAllAnimations()
            $0.birthRate = 0
            $0.emitterCells = nil
            $0.opacity = 0
        }

        balloonContainers.forEach {
            $0.removeAllAnimations()
            $0.opacity = 0
            $0.transform = CATransform3DIdentity
        }

        funTextContainer.layer?.removeAllAnimations()
        funTextContainer.layer?.opacity = 0
        funTextContainer.layer?.transform = CATransform3DIdentity
        funTextContainer.alphaValue = 0
        funTextContainer.isHidden = true
        funTitleLabel.layer?.removeAllAnimations()
        funTitleLabel.layer?.opacity = 0
        funSubtitleLabel.layer?.removeAllAnimations()
        funSubtitleLabel.layer?.opacity = 0
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    private func positionClassicPanel(on screen: NSScreen?) {
        guard let screen else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - classicPanel.frame.width / 2
        let y = visibleFrame.maxY - classicPanel.frame.height - 56
        classicPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func resolvedFunEffect(_ effect: FunCelebrationEffect) -> FunCelebrationEffect {
        guard effect == .auto else {
            return effect
        }

        let candidates: [FunCelebrationEffect] = [.confetti, .fireworks, .lightning, .balloons, .glowText]
        return candidates.randomElement() ?? .confetti
    }

    private func buildFunTextUI() {
        funTextContainer.translatesAutoresizingMaskIntoConstraints = false
        funTextContainer.wantsLayer = true
        funTextContainer.layer?.opacity = 0
        funTextContainer.layer?.shadowOpacity = 0
        funTextContainer.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        funTextContainer.alphaValue = 0
        funTextContainer.isHidden = true

        funTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        funTitleLabel.alignment = .center
        funTitleLabel.textColor = NSColor.white
        funTitleLabel.lineBreakMode = .byWordWrapping
        funTitleLabel.maximumNumberOfLines = 2
        funTitleLabel.wantsLayer = true
        funTitleLabel.layer?.shadowColor = NSColor.systemOrange.withAlphaComponent(0.95).cgColor
        funTitleLabel.layer?.shadowOpacity = 1
        funTitleLabel.layer?.shadowRadius = 30
        funTitleLabel.layer?.shadowOffset = .zero
        funTitleLabel.layer?.opacity = 0

        funSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        funSubtitleLabel.alignment = .center
        funSubtitleLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        funSubtitleLabel.lineBreakMode = .byWordWrapping
        funSubtitleLabel.maximumNumberOfLines = 2
        funSubtitleLabel.wantsLayer = true
        funSubtitleLabel.layer?.shadowColor = NSColor.systemPink.withAlphaComponent(0.6).cgColor
        funSubtitleLabel.layer?.shadowOpacity = 0.9
        funSubtitleLabel.layer?.shadowRadius = 16
        funSubtitleLabel.layer?.shadowOffset = .zero
        funSubtitleLabel.layer?.opacity = 0

        let stack = NSStackView(views: [funTitleLabel, funSubtitleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12

        funTextContainer.addSubview(stack)
        funRootView.addSubview(funTextContainer)

        NSLayoutConstraint.activate([
            funTextContainer.centerXAnchor.constraint(equalTo: funRootView.centerXAnchor),
            funTextContainer.centerYAnchor.constraint(equalTo: funRootView.centerYAnchor, constant: -18),
            funTextContainer.leadingAnchor.constraint(greaterThanOrEqualTo: funRootView.leadingAnchor, constant: 56),
            funTextContainer.trailingAnchor.constraint(lessThanOrEqualTo: funRootView.trailingAnchor, constant: -56),
            funTextContainer.widthAnchor.constraint(lessThanOrEqualTo: funRootView.widthAnchor, multiplier: 0.84),

            stack.leadingAnchor.constraint(equalTo: funTextContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: funTextContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: funTextContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: funTextContainer.bottomAnchor),
        ])
    }

    private func funMessageCopy(for timers: [TimerEntry]) -> (title: String, subtitle: String) {
        guard timers.count == 1, let timer = timers.first else {
            let names = timers
                .prefix(2)
                .map { TimeFormatting.timerName(label: $0.label, durationSeconds: $0.durationSeconds) }
                .joined(separator: "  •  ")
            let subtitle = names.isEmpty ? "Timer done!" : names
            return ("TIMERS DONE!", subtitle)
        }

        let title = TimeFormatting.timerName(label: timer.label, durationSeconds: timer.durationSeconds)
        return (title.isEmpty ? "TIMER DONE!" : title.uppercased(), "Timer done!")
    }

    private func makeConfettiCells() -> [CAEmitterCell] {
        let colors: [NSColor] = [
            .systemPink,
            .systemOrange,
            .systemYellow,
            .systemGreen,
            .systemTeal,
            .systemBlue,
            .systemPurple,
        ]
        let images = [
            Self.makeConfettiImage(size: CGSize(width: 10, height: 16), cornerRadius: 3),
            Self.makeConfettiImage(size: CGSize(width: 12, height: 6), cornerRadius: 3),
        ].compactMap { $0 }

        return colors.enumerated().map { index, color in
            let cell = CAEmitterCell()
            cell.contents = images[index % images.count]
            cell.birthRate = 8
            cell.lifetime = 3.6
            cell.lifetimeRange = 0.8
            cell.velocity = 220
            cell.velocityRange = 90
            cell.yAcceleration = -260
            cell.emissionLongitude = -CGFloat.pi / 2
            cell.emissionRange = CGFloat.pi / 4
            cell.spin = 4
            cell.spinRange = 5
            cell.scale = 0.95
            cell.scaleRange = 0.42
            cell.color = color.cgColor
            return cell
        }
    }

    private static func makeConfettiImage(size: CGSize, cornerRadius: CGFloat) -> CGImage? {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: cornerRadius, yRadius: cornerRadius).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    private func makeFireworkBurstCells(color: NSColor) -> [CAEmitterCell] {
        guard let particleImage = Self.makeParticleImage(diameter: 28) else {
            return []
        }

        let spark = CAEmitterCell()
        spark.contents = particleImage
        spark.birthRate = 460
        spark.lifetime = 1.35
        spark.lifetimeRange = 0.3
        spark.velocity = 240
        spark.velocityRange = 80
        spark.yAcceleration = -90
        spark.emissionRange = .pi * 2
        spark.scale = 0.15
        spark.scaleRange = 0.08
        spark.scaleSpeed = -0.06
        spark.alphaSpeed = -0.88
        spark.spin = 3.2
        spark.spinRange = 6
        spark.color = color.cgColor

        let glitter = CAEmitterCell()
        glitter.contents = particleImage
        glitter.birthRate = 220
        glitter.lifetime = 1.0
        glitter.lifetimeRange = 0.24
        glitter.velocity = 140
        glitter.velocityRange = 44
        glitter.yAcceleration = -70
        glitter.emissionRange = .pi * 2
        glitter.scale = 0.08
        glitter.scaleRange = 0.04
        glitter.scaleSpeed = -0.04
        glitter.alphaSpeed = -1.0
        glitter.spinRange = 6
        glitter.color = NSColor.white.withAlphaComponent(0.95).cgColor

        return [spark, glitter]
    }

    private static func makeParticleImage(diameter: CGFloat) -> CGImage? {
        let pixels = Int(diameter)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        let rect = NSRect(x: 0, y: 0, width: diameter, height: diameter)
        let gradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.95),
            NSColor.white.withAlphaComponent(0.55),
            NSColor.white.withAlphaComponent(0.08),
            .clear,
        ])
        gradient?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    private func balloonColor(at index: Int) -> NSColor {
        let colors: [NSColor] = [
            .systemPink,
            .systemOrange,
            .systemYellow,
            .systemGreen,
            .systemTeal,
            .systemBlue,
            .systemPurple,
        ]
        return colors[index % colors.count]
    }
}

private extension NSColor {
    func darker(amount: CGFloat) -> NSColor {
        guard let color = usingColorSpace(.deviceRGB) else {
            return self
        }
        return NSColor(
            red: max(0, color.redComponent - amount),
            green: max(0, color.greenComponent - amount),
            blue: max(0, color.blueComponent - amount),
            alpha: color.alphaComponent
        )
    }
}
