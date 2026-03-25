import Foundation

public struct Preferences: Codable, Equatable, Sendable {
    public var alwaysShowMenuBarItem: Bool
    public var showNextTimerInMenuBar: Bool
    public var playSoundOnCompletion: Bool
    public var recentHistoryCount: Int
    public var launchAtLogin: Bool
    public var hotkeyKeyCode: UInt32
    public var hotkeyModifiers: UInt32
    public var completionSound: String

    /// Default: Cmd+Shift+T (kVK_ANSI_T = 0x11, cmdKey | shiftKey = 0x0500)
    public init(
        alwaysShowMenuBarItem: Bool = true,
        showNextTimerInMenuBar: Bool = true,
        playSoundOnCompletion: Bool = true,
        recentHistoryCount: Int = 10,
        launchAtLogin: Bool = false,
        hotkeyKeyCode: UInt32 = 0x11,
        hotkeyModifiers: UInt32 = 0x0500,
        completionSound: String = "Glass"
    ) {
        self.alwaysShowMenuBarItem = alwaysShowMenuBarItem
        self.showNextTimerInMenuBar = showNextTimerInMenuBar
        self.playSoundOnCompletion = playSoundOnCompletion
        self.recentHistoryCount = recentHistoryCount
        self.launchAtLogin = launchAtLogin
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.completionSound = completionSound
    }
}
