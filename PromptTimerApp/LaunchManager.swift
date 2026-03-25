import Foundation
import PromptTimerCore
import ServiceManagement

@MainActor
final class LaunchManager {
    private let logger = PromptTimerLogger(category: "LaunchManager")

    func applyPreference(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
                logger.info("Launch at login enabled")
            } else {
                try service.unregister()
                logger.info("Launch at login disabled")
            }
        } catch {
            logger.error("Launch at login failed: \(error.localizedDescription)")
        }
    }
}
