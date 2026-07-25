import AppKit
import ApplicationServices

/// Locates a concrete on-screen window and everything needed to address it later.
///
/// Three subsystems each know a different half of the truth: `CGWindowList` knows z-order,
/// geometry and window IDs but hands out no AX handles; the AX API hands out handles and
/// live move/resize events but has no notion of "the window under the cursor";
/// ScreenCaptureKit needs the `CGWindowID`. We bridge them by matching on owner pid + frame.
enum WindowFinder {

    /// Everything DeskPins needs to keep track of one window.
    struct Target {
        let window: AXUIElement
        let windowID: CGWindowID
        let pid: pid_t
        let name: String
    }

    struct ScreenWindow {
        let windowID: CGWindowID
        let pid: pid_t
        let frame: CGRect      // Quartz coordinates
        let title: String
        let appName: String
    }

    /// Every regular, on-screen window, front to back.
    private static func screenWindows() -> [ScreenWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let ownPid = ProcessInfo.processInfo.processIdentifier

        return raw.compactMap { entry in
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPid,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let frame = rect(from: bounds)
            else { return nil }

            return ScreenWindow(
                windowID: id,
                pid: pid,
                frame: frame,
                title: entry[kCGWindowName as String] as? String ?? "",
                appName: entry[kCGWindowOwnerName as String] as? String ?? "")
        }
    }

    /// IDs of every window currently on screen.
    ///
    /// `optionOnScreenOnly` only reports windows belonging to the Space the user is looking
    /// at, which is exactly how DeskPins tells whether a pinned window came along or was
    /// left behind on another desktop.
    static func onScreenWindowIDs() -> Set<CGWindowID> {
        Set(screenWindows().map(\.windowID))
    }

    /// The focused window of the frontmost application.
    static func frontmostTarget() -> Target? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return nil }

        let app = AXUIElementCreateApplication(front.processIdentifier)
        guard let value = AX.attribute(app, kAXFocusedWindowAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }

        let window = value as! AXUIElement
        guard let frame = AX.frame(window) else { return nil }

        // Recover the CGWindowID by matching geometry within the same process.
        let candidates = screenWindows().filter { $0.pid == front.processIdentifier }
        guard let screen = candidates.min(by: { distance($0.frame, frame) < distance($1.frame, frame) }),
              distance(screen.frame, frame) < 8
        else { return nil }

        return Target(window: window,
                      windowID: screen.windowID,
                      pid: front.processIdentifier,
                      name: displayName(screen, axTitle: AX.title(window)))
    }

    /// Finds the AX handle that corresponds to a window we already located via CGWindowList.
    private static func target(matching screen: ScreenWindow) -> Target? {
        let app = AXUIElementCreateApplication(screen.pid)
        let candidates = AX.elements(app, kAXWindowsAttribute)
        guard !candidates.isEmpty else { return nil }

        // Match on geometry: titles are unreliable (empty, duplicated, or localized).
        let matched = candidates.min { a, b in
            distance(AX.frame(a), screen.frame) < distance(AX.frame(b), screen.frame)
        }
        guard let window = matched, distance(AX.frame(window), screen.frame) < 8 else { return nil }

        return Target(window: window,
                      windowID: screen.windowID,
                      pid: screen.pid,
                      name: displayName(screen, axTitle: AX.title(window)))
    }

    private static func displayName(_ screen: ScreenWindow, axTitle: String?) -> String {
        let title = axTitle?.isEmpty == false ? axTitle! : screen.title
        return title.isEmpty ? screen.appName : "\(screen.appName) — \(title)"
    }

    private static func rect(from bounds: [String: CGFloat]) -> CGRect? {
        guard let x = bounds["X"], let y = bounds["Y"],
              let w = bounds["Width"], let h = bounds["Height"] else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func distance(_ a: CGRect?, _ b: CGRect) -> CGFloat {
        guard let a else { return .greatestFiniteMagnitude }
        return abs(a.minX - b.minX) + abs(a.minY - b.minY)
             + abs(a.width - b.width) + abs(a.height - b.height)
    }
}
