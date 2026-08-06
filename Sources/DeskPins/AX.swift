import ApplicationServices
import AppKit

/// Thin, typed wrappers around the Accessibility C API.
enum AX {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        attribute(element, name) as? [AXUIElement] ?? []
    }

    static func point(_ element: AXUIElement, _ name: String) -> CGPoint? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ element: AXUIElement, _ name: String) -> CGSize? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    /// Window frame in Quartz coordinates (origin top-left of the primary display).
    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let origin = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func pid(_ element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    static func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    static func title(_ element: AXUIElement) -> String? {
        attribute(element, kAXTitleAttribute) as? String
    }

    /// True once the user has granted Accessibility access in System Settings.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks for Accessibility access, showing the system prompt when `prompt` is true.
    @discardableResult
    static func requestTrust(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

/// Deep links into the Privacy & Security panes the app sends users to.
enum PrivacySettings {
    /// The anchor identifying a row inside Privacy & Security.
    enum Pane: String {
        case accessibility = "Privacy_Accessibility"
        case screenRecording = "Privacy_ScreenCapture"
    }

    private static let settingsBundleID = "com.apple.systempreferences"

    /// Opens System Settings on `pane`.
    ///
    /// **[constraint]** The anchor is dropped when System Settings has to launch first:
    /// the app comes up on General and the deep link is lost. Measured on macOS 26 — a
    /// cold open lands on General with both the `com.apple.preference.security` identifier
    /// and the newer `com.apple.settings.PrivacySecurity.extension` one, and both navigate
    /// correctly once it is already running. The identifier is therefore not the problem
    /// and an OS-version switch does not help; the launch is. So the URL is sent a second
    /// time once the app is up. 0.5 s was enough in testing, 0.8 s is the margin.
    ///
    /// A first launch is exactly when this is hit, since System Settings is rarely open —
    /// which is why the permission warnings appeared to open the wrong pane.
    static func open(_ pane: Pane) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!
        let isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: settingsBundleID).isEmpty

        NSWorkspace.shared.open(url)
        guard !isRunning else { return }   // already warm: the first open navigates

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Conversions between Quartz (top-left origin) and Cocoa (bottom-left origin) coordinates.
enum Coord {
    private static var flipHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    static func cocoa(from quartz: CGRect) -> NSRect {
        NSRect(x: quartz.origin.x,
               y: flipHeight - quartz.origin.y - quartz.height,
               width: quartz.width,
               height: quartz.height)
    }
}
