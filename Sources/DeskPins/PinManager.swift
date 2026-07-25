import AppKit
import ApplicationServices

/// Owns every pin and decides, on each front-app change, which pins need mirroring.
///
/// macOS has no public API to set another application's window level, and z-order for
/// ordinary windows is application-centric: the active app's windows always sit above
/// everyone else's. So "always on top" is delivered by `WindowMirror` — a panel we own,
/// at a floating level, showing the target window's live content. This class only decides
/// when each mirror should be running.
final class PinManager {
    static let shared = PinManager()

    private(set) var pins: [Pin] = []
    var onChange: (() -> Void)?
    var onMirrorFailure: ((String) -> Void)?

    private var updateScheduled = false
    private var pendingAllowsRaise = false

    private init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(frontAppChanged),
                           name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appTerminated(_:)),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(spaceChanged),
                           name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    // MARK: - Pin lifecycle

    enum PinResult {
        case pinned(String)
        case unpinned(String)
        case noWindow
        case failed
    }

    @discardableResult
    func pin(_ target: WindowFinder.Target) -> PinResult {
        if let existing = pins.first(where: { $0.windowID == target.windowID }) {
            return .pinned(existing.name)
        }
        guard let pin = Pin(target: target) else { return .failed }
        pin.onRemove = { [weak self] pin, reveal in self?.remove(pin, reveal: reveal) }
        pin.onFocusChanged = { [weak self] in self?.scheduleUpdate(allowRaise: false) }
        pin.onMirrorFailure = { [weak self] pin, reason in
            self?.onMirrorFailure?(reason)
            self?.remove(pin)
        }
        pins.append(pin)
        pin.raiseWithinApp()
        onChange?()
        updateMirrors()
        return .pinned(target.name)
    }

    /// Pins the window, or unpins it when it is pinned already.
    func toggle(_ target: WindowFinder.Target) -> PinResult {
        if let existing = pins.first(where: { $0.windowID == target.windowID }) {
            remove(existing)
            return .unpinned(existing.name)
        }
        return pin(target)
    }

    /// - Parameter reveal: bring the real window forward. Unpinning a window whose app is
    ///   in the background otherwise just makes the mirror vanish, leaving the window
    ///   buried where the user cannot see it went anywhere.
    func remove(_ pin: Pin, reveal: Bool = false) {
        guard let index = pins.firstIndex(where: { $0 === pin }) else { return }
        let wasBuried = pin.isShowingMirror
        pins[index].tearDown()
        pins.remove(at: index)
        if reveal && wasBuried { pin.activateRealWindow() }
        onChange?()
    }

    func removeAll() {
        pins.forEach { $0.tearDown() }
        pins.removeAll()
        onChange?()
    }

    // MARK: - Driving the mirrors

    @objc private func frontAppChanged() { scheduleUpdate(allowRaise: true) }

    /// Switching Spaces must never raise anything. `AXRaise` on a window that lives on
    /// another Space makes macOS jump back to that Space — which, on a freshly created
    /// desktop, looks like the system refusing to let you leave the one with the pins.
    @objc private func spaceChanged() { scheduleUpdate(allowRaise: false) }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        pins.filter { $0.pid == app.processIdentifier }.forEach { remove($0) }
    }

    /// Coalesces the burst of notifications an app switch produces into one update.
    private func scheduleUpdate(allowRaise: Bool) {
        guard !pins.isEmpty else { return }
        // If any pending update may raise, keep that — an activation is the one moment
        // where reordering the app's own windows is what the user asked for.
        pendingAllowsRaise = pendingAllowsRaise || allowRaise
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            let raise = self.pendingAllowsRaise
            self.pendingAllowsRaise = false
            self.updateMirrors(allowRaise: raise)
        }
    }

    private func updateMirrors(allowRaise: Bool = false) {
        pins.filter { !$0.isAlive }.forEach { remove($0) }
        guard !pins.isEmpty else { return }

        guard let frontPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else { return }
        // Our own menu briefly makes DeskPins frontmost; that must not tear the mirrors down.
        guard frontPid != ProcessInfo.processInfo.processIdentifier else { return }

        // Only windows on the Space the user is looking at right now.
        let onScreen = WindowFinder.onScreenWindowIDs()
        let present = pins.filter { onScreen.contains($0.windowID) }

        for pin in pins {
            let onCurrentSpace = onScreen.contains(pin.windowID)
            // "Active" means the user is working in this very window — its own app is in
            // front and this is the window that app has focused. A different window of the
            // same app being raised over it does not count, which is what keeps the pinned
            // window visible above its siblings.
            let isActive = onCurrentSpace && pin.pid == frontPid && pin.isFocusedInApp
            let hasCompany = present.contains { $0 !== pin }

            pin.apply(Pin.Placement(onCurrentSpace: onCurrentSpace,
                                    isActive: isActive,
                                    hasCompany: hasCompany))
            if allowRaise && isActive { pin.raiseWithinApp() }
        }
    }
}
