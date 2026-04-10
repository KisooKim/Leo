import Foundation
import ServiceManagement

/// Wrapper around `SMAppService.mainApp` for toggling Launch-at-Login.
/// Requires macOS 13+, which matches our deployment target.
final class LoginItemManager {
    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    /// Registers the app as a login item. Throws if registration fails.
    func enable() throws {
        try service.register()
    }

    /// Unregisters. Throws if unregistration fails.
    func disable() throws {
        try service.unregister()
    }

    func toggle() throws {
        if isEnabled { try disable() } else { try enable() }
    }
}
