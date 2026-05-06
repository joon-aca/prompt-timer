import AppKit
import Foundation
import PromptTimerCore

@MainActor
final class ApplicationLauncher {
    private let logger = PromptTimerLogger(category: "ApplicationLauncher")
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func validatedAction(for action: TimerAction?) throws -> TimerAction? {
        guard let action else {
            return nil
        }

        switch action.kind {
        case .launchApplication:
            let resolved = try resolveApplication(for: action.target)
            return .launchApplication(target: resolved.identifier, displayName: resolved.displayName)
        }
    }

    func perform(_ action: TimerAction) {
        switch action.kind {
        case .launchApplication:
            do {
                let resolved = try resolveApplication(for: action.target)
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(
                    at: resolved.url,
                    configuration: configuration
                ) { [logger] _, error in
                    if let error {
                        logger.error("Failed launching \(resolved.displayName): \(error.localizedDescription)")
                    }
                }
            } catch {
                logger.error("Failed resolving launch target \(action.target): \(error.localizedDescription)")
            }
        }
    }

    private func resolveApplication(for rawTarget: String) throws -> ResolvedApplication {
        let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            throw ApplicationLauncherError.applicationNotFound(rawTarget)
        }

        if let application = resolveNaturalLanguageAlias(target) {
            return application
        }

        if let application = resolveBundleIdentifier(target) {
            return application
        }

        if let application = resolveExactApplicationName(target) {
            return application
        }

        if let application = resolveApplicationPath(target) {
            return application
        }

        if let application = resolveFuzzyApplicationName(target) {
            return application
        }

        throw ApplicationLauncherError.applicationNotFound(target)
    }

    private func resolveNaturalLanguageAlias(_ target: String) -> ResolvedApplication? {
        guard let alias = Self.applicationAliases[normalizeAlias(target)] else {
            return nil
        }

        for bundleIdentifier in alias.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
               let resolved = makeResolvedApplication(url: url) {
                return resolved
            }
        }

        for scheme in alias.urlSchemes {
            if let url = URL(string: "\(scheme):"),
               let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url),
               let resolved = makeResolvedApplication(url: applicationURL) {
                return resolved
            }
        }

        for name in alias.applicationNames {
            if let resolved = resolveExactApplicationName(name) ?? resolveFuzzyApplicationName(name) {
                return resolved
            }
        }

        return nil
    }

    private func resolveBundleIdentifier(_ target: String) -> ResolvedApplication? {
        guard target.contains("."), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) else {
            return nil
        }
        return makeResolvedApplication(url: url)
    }

    private func resolveExactApplicationName(_ target: String) -> ResolvedApplication? {
        for directory in Self.applicationDirectories {
            for candidate in [target, target + ".app"] {
                let url = URL(fileURLWithPath: directory, isDirectory: true).appendingPathComponent(candidate)
                if fileManager.fileExists(atPath: url.path) {
                    return makeResolvedApplication(url: url)
                }
            }
        }
        return nil
    }

    private func resolveApplicationPath(_ target: String) -> ResolvedApplication? {
        guard target.contains("/") || target.hasPrefix("~") || target.hasSuffix(".app") else {
            return nil
        }

        let expandedPath = NSString(string: target).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return makeResolvedApplication(url: url)
    }

    private func resolveFuzzyApplicationName(_ target: String) -> ResolvedApplication? {
        let normalizedTarget = normalize(target)
        var matches: [ResolvedApplication] = []

        for directory in Self.applicationDirectories {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: directory, isDirectory: true),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                let appName = normalize(url.deletingPathExtension().lastPathComponent)
                if appName == normalizedTarget || appName.contains(normalizedTarget) || normalizedTarget.contains(appName) {
                    if let resolved = makeResolvedApplication(url: url) {
                        matches.append(resolved)
                    }
                }
            }
        }

        return matches.sorted { lhs, rhs in
            if lhs.displayName.count == rhs.displayName.count {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.displayName.count < rhs.displayName.count
        }.first
    }

    private func makeResolvedApplication(url: URL) -> ResolvedApplication? {
        let bundle = Bundle(url: url)
        let identifier = bundle?.bundleIdentifier ?? url.path
        let displayName =
            (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? url.deletingPathExtension().lastPathComponent

        return ResolvedApplication(url: url, identifier: identifier, displayName: displayName)
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func normalizeAlias(_ value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let applicationDirectories = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSString(string: "~/Applications").expandingTildeInPath,
    ]

    private static let applicationAliases: [String: ApplicationAlias] = [
        "browser": ApplicationAlias(urlSchemes: ["https"], applicationNames: ["Safari", "Google Chrome"]),
        "calendar": ApplicationAlias(bundleIdentifiers: ["com.apple.iCal"], applicationNames: ["Calendar"]),
        "chrome": ApplicationAlias(bundleIdentifiers: ["com.google.Chrome"], applicationNames: ["Google Chrome"]),
        "email": ApplicationAlias(urlSchemes: ["mailto"], applicationNames: ["Mail"]),
        "facetime": ApplicationAlias(bundleIdentifiers: ["com.apple.FaceTime"], applicationNames: ["FaceTime"]),
        "gmail": ApplicationAlias(urlSchemes: ["mailto"], applicationNames: ["Mail"]),
        "mail": ApplicationAlias(urlSchemes: ["mailto"], applicationNames: ["Mail"]),
        "messages": ApplicationAlias(bundleIdentifiers: ["com.apple.MobileSMS"], applicationNames: ["Messages"]),
        "microsoft teams": ApplicationAlias(
            bundleIdentifiers: ["com.microsoft.teams2", "com.microsoft.teams"],
            applicationNames: ["Microsoft Teams"]
        ),
        "safari": ApplicationAlias(bundleIdentifiers: ["com.apple.Safari"], applicationNames: ["Safari"]),
        "slack": ApplicationAlias(bundleIdentifiers: ["com.tinyspeck.slackmacgap"], applicationNames: ["Slack"]),
        "teams": ApplicationAlias(
            bundleIdentifiers: ["com.microsoft.teams2", "com.microsoft.teams"],
            applicationNames: ["Microsoft Teams"]
        ),
        "zoom": ApplicationAlias(bundleIdentifiers: ["us.zoom.xos"], applicationNames: ["zoom.us", "Zoom"]),
    ]
}

private struct ResolvedApplication {
    let url: URL
    let identifier: String
    let displayName: String
}

private struct ApplicationAlias {
    var bundleIdentifiers: [String]
    var urlSchemes: [String]
    var applicationNames: [String]

    init(
        bundleIdentifiers: [String] = [],
        urlSchemes: [String] = [],
        applicationNames: [String] = []
    ) {
        self.bundleIdentifiers = bundleIdentifiers
        self.urlSchemes = urlSchemes
        self.applicationNames = applicationNames
    }
}

private enum ApplicationLauncherError: LocalizedError {
    case applicationNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .applicationNotFound(target):
            return "Could not find an application matching `\(target)`."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
