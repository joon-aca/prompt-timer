// swift-tools-version: 6.0
import PackageDescription

let coreSources = [
    "PromptTimerApp/Models/TimerState.swift",
    "PromptTimerApp/Models/TimerEntry.swift",
    "PromptTimerApp/Models/AppState.swift",
    "PromptTimerApp/Models/Preferences.swift",
    "PromptTimerApp/Models/IPCCommand.swift",
    "PromptTimerApp/Models/IPCResponse.swift",
    "PromptTimerApp/Utilities/DurationParser.swift",
    "PromptTimerApp/Utilities/TimeFormatting.swift",
    "PromptTimerApp/Utilities/AtomicFileStore.swift",
    "PromptTimerApp/Utilities/Logger.swift",
    "PromptTimerApp/TimerStore.swift",
    "PromptTimerApp/TimerManager.swift",
]

let package = Package(
    name: "PromptTimer",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "PromptTimerCore", targets: ["PromptTimerCore"]),
        .library(name: "TimerCLI", targets: ["TimerCLI"]),
        .executable(name: "PromptTimerAgent", targets: ["PromptTimerAgent"]),
        .executable(name: "timer", targets: ["timer"]),
    ],
    targets: [
        .target(
            name: "PromptTimerCore",
            path: "PromptTimerApp",
            exclude: [
                "AppDelegate.swift",
                "PromptTimerApp.swift",
                "StatusItemController.swift",
                "NotificationManager.swift",
                "PreferencesController.swift",
                "QuickAddWindowController.swift",
                "IPCServer.swift",
                "LaunchManager.swift",
                "WakeMonitor.swift",
            ],
            sources: [
                "Models/TimerState.swift",
                "Models/TimerEntry.swift",
                "Models/AppState.swift",
                "Models/Preferences.swift",
                "Models/IPCCommand.swift",
                "Models/IPCResponse.swift",
                "Utilities/DurationParser.swift",
                "Utilities/TimeFormatting.swift",
                "Utilities/AtomicFileStore.swift",
                "Utilities/Logger.swift",
                "TimerStore.swift",
                "TimerManager.swift",
            ]
        ),
        .executableTarget(
            name: "PromptTimerAgent",
            dependencies: ["PromptTimerCore"],
            path: "PromptTimerApp",
            exclude: [
                "Models",
                "Utilities",
                "TimerStore.swift",
                "TimerManager.swift",
            ],
            sources: [
                "AppDelegate.swift",
                "PromptTimerApp.swift",
                "StatusItemController.swift",
                "NotificationManager.swift",
                "PreferencesController.swift",
                "QuickAddWindowController.swift",
                "IPCServer.swift",
                "LaunchManager.swift",
                "WakeMonitor.swift",
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .target(
            name: "TimerCLI",
            dependencies: ["PromptTimerCore"],
            path: "TimerCLI",
            exclude: [
                "main.swift",
            ],
            sources: [
                "CLIParser.swift",
                "IPCClient.swift",
                "OutputFormatter.swift",
                "AgentLauncher.swift",
                "VerboseLogger.swift",
            ]
        ),
        .executableTarget(
            name: "timer",
            dependencies: ["PromptTimerCore", "TimerCLI"],
            path: "TimerCLI",
            exclude: [
                "CLIParser.swift",
                "IPCClient.swift",
                "OutputFormatter.swift",
                "AgentLauncher.swift",
                "VerboseLogger.swift",
            ],
            sources: [
                "main.swift",
            ]
        ),
        .testTarget(
            name: "PromptTimerTests",
            dependencies: ["PromptTimerCore", "TimerCLI"],
            path: "PromptTimerTests"
        ),
    ]
)
