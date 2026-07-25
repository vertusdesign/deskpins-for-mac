import Foundation
import ServiceManagement

/// Start DeskPins when the user logs in.
///
/// `SMAppService` is the supported route since macOS 13 — it registers the app itself,
/// with no helper bundle and no login-item plist, and the user can always override it in
/// System Settings → General → Login Items.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True when macOS has the registration but the user has switched it off, in which
    /// case only they can turn it back on.
    static var needsUserApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
