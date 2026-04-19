import Foundation
import PromptTimerCore
import ServiceManagement

struct LaunchAtLoginState: Equatable {
    let isEnabled: Bool
    let detail: String
}

@MainActor
final class LaunchManager {
    private let logger = PromptTimerLogger(category: "LaunchManager")
    var onStatusChange: ((LaunchAtLoginState) -> Void)?

    @discardableResult
    func applyPreference(_ enabled: Bool) -> LaunchAtLoginState {
        let service = SMAppService.mainApp
        var lastError: Error?
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
                logger.info("Launch at login enabled")
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
                logger.info("Launch at login disabled")
            }
        } catch {
            lastError = error
            logger.error("Launch at login failed: \(error.localizedDescription)")
        }

        let state = makeState(for: service.status, error: lastError)
        onStatusChange?(state)
        return state
    }

    @discardableResult
    func refreshStatus() -> LaunchAtLoginState {
        let state = makeState(for: SMAppService.mainApp.status, error: nil)
        onStatusChange?(state)
        return state
    }

    private func makeState(for status: SMAppService.Status, error: Error?) -> LaunchAtLoginState {
        if let error {
            return LaunchAtLoginState(
                isEnabled: status == .enabled,
                detail: "Launch at login failed: \(error.localizedDescription)"
            )
        }

        switch status {
        case .enabled:
            return LaunchAtLoginState(
                isEnabled: true,
                detail: "Prompt Timer will open automatically when you log in."
            )
        case .requiresApproval:
            return LaunchAtLoginState(
                isEnabled: false,
                detail: "Approve Prompt Timer in System Settings > General > Login Items."
            )
        case .notRegistered:
            return LaunchAtLoginState(
                isEnabled: false,
                detail: "Prompt Timer stays off until you turn on launch at login."
            )
        case .notFound:
            return LaunchAtLoginState(
                isEnabled: false,
                detail: "Launch at login is unavailable in this build."
            )
        @unknown default:
            return LaunchAtLoginState(
                isEnabled: false,
                detail: "Launch at login status is unavailable."
            )
        }
    }
}
