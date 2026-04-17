import Foundation

public enum CompletionCelebrationStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case classic
    case fun

    public var displayName: String {
        switch self {
        case .classic:
            return "Classic"
        case .fun:
            return "Fun"
        }
    }
}

public enum FunCelebrationEffect: String, Codable, CaseIterable, Equatable, Sendable {
    case auto
    case confetti
    case fireworks
    case lightning
    case balloons
    case glowText

    public var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .confetti:
            return "Confetti"
        case .fireworks:
            return "Fireworks"
        case .lightning:
            return "Lightning"
        case .balloons:
            return "Balloons"
        case .glowText:
            return "Glow Text"
        }
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var alwaysShowMenuBarItem: Bool
    public var showNextTimerInMenuBar: Bool
    public var playSoundOnCompletion: Bool
    public var recentHistoryCount: Int
    public var launchAtLogin: Bool
    public var hotkeyKeyCode: UInt32
    public var hotkeyModifiers: UInt32
    public var completionSound: String
    public var completionCelebrationStyle: CompletionCelebrationStyle
    public var funCelebrationEffect: FunCelebrationEffect

    /// Default: Cmd+Shift+T (kVK_ANSI_T = 0x11, cmdKey | shiftKey = 0x0500)
    public init(
        alwaysShowMenuBarItem: Bool = true,
        showNextTimerInMenuBar: Bool = true,
        playSoundOnCompletion: Bool = true,
        recentHistoryCount: Int = 10,
        launchAtLogin: Bool = false,
        hotkeyKeyCode: UInt32 = 0x11,
        hotkeyModifiers: UInt32 = 0x0500,
        completionSound: String = "Glass",
        completionCelebrationStyle: CompletionCelebrationStyle = .classic,
        funCelebrationEffect: FunCelebrationEffect = .auto
    ) {
        self.alwaysShowMenuBarItem = alwaysShowMenuBarItem
        self.showNextTimerInMenuBar = showNextTimerInMenuBar
        self.playSoundOnCompletion = playSoundOnCompletion
        self.recentHistoryCount = recentHistoryCount
        self.launchAtLogin = launchAtLogin
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.completionSound = completionSound
        self.completionCelebrationStyle = completionCelebrationStyle
        self.funCelebrationEffect = funCelebrationEffect
    }

    private enum CodingKeys: String, CodingKey {
        case alwaysShowMenuBarItem
        case showNextTimerInMenuBar
        case playSoundOnCompletion
        case recentHistoryCount
        case launchAtLogin
        case hotkeyKeyCode
        case hotkeyModifiers
        case completionSound
        case completionCelebrationStyle
        case funCelebrationEffect
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alwaysShowMenuBarItem = try container.decode(Bool.self, forKey: .alwaysShowMenuBarItem)
        showNextTimerInMenuBar = try container.decode(Bool.self, forKey: .showNextTimerInMenuBar)
        playSoundOnCompletion = try container.decode(Bool.self, forKey: .playSoundOnCompletion)
        recentHistoryCount = try container.decode(Int.self, forKey: .recentHistoryCount)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        hotkeyKeyCode = try container.decode(UInt32.self, forKey: .hotkeyKeyCode)
        hotkeyModifiers = try container.decode(UInt32.self, forKey: .hotkeyModifiers)
        completionSound = try container.decode(String.self, forKey: .completionSound)
        completionCelebrationStyle =
            try container.decodeIfPresent(CompletionCelebrationStyle.self, forKey: .completionCelebrationStyle) ?? .classic
        funCelebrationEffect =
            try container.decodeIfPresent(FunCelebrationEffect.self, forKey: .funCelebrationEffect) ?? .auto
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alwaysShowMenuBarItem, forKey: .alwaysShowMenuBarItem)
        try container.encode(showNextTimerInMenuBar, forKey: .showNextTimerInMenuBar)
        try container.encode(playSoundOnCompletion, forKey: .playSoundOnCompletion)
        try container.encode(recentHistoryCount, forKey: .recentHistoryCount)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(hotkeyKeyCode, forKey: .hotkeyKeyCode)
        try container.encode(hotkeyModifiers, forKey: .hotkeyModifiers)
        try container.encode(completionSound, forKey: .completionSound)
        try container.encode(completionCelebrationStyle, forKey: .completionCelebrationStyle)
        try container.encode(funCelebrationEffect, forKey: .funCelebrationEffect)
    }
}
