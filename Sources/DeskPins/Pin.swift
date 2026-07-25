import AppKit
import ApplicationServices

/// One pinned window: the AX handle, its mirror, its marker, and an event subscription that
/// keeps both glued to the window. Everything here is event-driven — no polling, so a pin
/// whose app is in the foreground costs nothing at all.
final class Pin {
    let window: AXUIElement
    let windowID: CGWindowID
    let pid: pid_t
    let name: String
    /// The owning application, needed to ask which of its windows has focus.
    let appElement: AXUIElement

    private var observer: AXObserver?
    private var marker: PinMarker!
    private var mirror: WindowMirror!
    private var isMinimized = false
    private var isMirroring = false

    private var isDragging = false
    private var dragMonitors: [Any] = []
    private var dragFallback: Timer?

    /// Called when the window goes away or the user clicks the marker. The flag says
    /// whether the real window is still there and should be brought forward.
    var onRemove: ((Pin, _ reveal: Bool) -> Void)?
    /// Called when mirroring fails, with a short reason.
    var onMirrorFailure: ((Pin, String) -> Void)?
    /// Called when the owning application focuses a different window, which changes
    /// whether this pin still needs its mirror.
    var onFocusChanged: (() -> Void)?

    init?(target: WindowFinder.Target) {
        window = target.window
        windowID = target.windowID
        pid = target.pid
        name = target.name
        appElement = AXUIElementCreateApplication(target.pid)

        marker = PinMarker { [weak self] in
            guard let self else { return }
            self.onRemove?(self, true)      // user unpinned it; the window still exists
        }

        mirror = WindowMirror(windowID: target.windowID)
        mirror.onClick = { [weak self] in self?.activateRealWindow() }
        mirror.onFailure = { [weak self] reason in
            guard let self else { return }
            self.onMirrorFailure?(self, reason)
        }

        guard subscribe() else { return nil }
        syncGeometry()
    }

    // MARK: - AX notifications

    private static let notifications = [
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXUIElementDestroyedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
    ]

    private func subscribe() -> Bool {
        var created: AXObserver?
        guard AXObserverCreate(pid, pinObserverCallback, &created) == .success,
              let observer = created else { return false }
        self.observer = observer

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for note in Pin.notifications {
            AXObserverAddNotification(observer, window, note as CFString, refcon)
        }
        // Watched on the application, not the window: this is how DeskPins learns that a
        // *different* window of the same app was brought forward over the pinned one.
        AXObserverAddNotification(observer, appElement,
                                  kAXFocusedWindowChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           AXObserverGetRunLoopSource(observer),
                           .defaultMode)
        return true
    }

    fileprivate func handle(_ notification: String) {
        switch notification {
        case kAXUIElementDestroyedNotification:
            onRemove?(self, false)          // nothing left to bring forward
        case kAXWindowMiniaturizedNotification:
            isMinimized = true
            endDrag()
            marker.hide()
            mirror.hide()
        case kAXWindowDeminiaturizedNotification:
            isMinimized = false
            syncGeometry()
            applyMirroring()
        case kAXFocusedWindowChangedNotification:
            onFocusChanged?()
        case kAXWindowMovedNotification:
            beginDragIfNeeded()
            syncGeometry()
        default:
            syncGeometry()
        }
    }

    // MARK: - Window drags

    /// Accessibility reports every step of a drag but never reports its end, so the badge
    /// is faded out on the first move and faded back in when the mouse button comes up.
    private func beginDragIfNeeded() {
        guard !isDragging else {
            armDragFallback()
            return
        }
        isDragging = true
        marker.suppressForDrag()
        applyMirroring()                // fall back to the real window while it moves

        // The drag happens in another application, so a global monitor sees the mouse-up;
        // the local one covers the case where the event is delivered to us instead.
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.endDrag() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp],
                                                          handler: handler) {
            dragMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp],
                                                        handler: { event in
            handler(event)
            return event
        }) {
            dragMonitors.append(local)
        }
        armDragFallback()
    }

    /// Not every move comes from a mouse drag — windows are also moved by keyboard, by
    /// Stage Manager, or by another app. Without a mouse-up the badge comes back on idle.
    private func armDragFallback() {
        dragFallback?.invalidate()
        dragFallback = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) {
            [weak self] _ in self?.endDrag()
        }
    }

    private func endDrag() {
        guard isDragging else { return }
        isDragging = false
        dragFallback?.invalidate()
        dragFallback = nil
        dragMonitors.forEach(NSEvent.removeMonitor)
        dragMonitors.removeAll()

        syncGeometry()                  // pick up where the window actually landed
        applyMirroring()
        marker.endDragSuppression()
    }

    // MARK: - State

    /// True while the window still exists and can be addressed.
    var isAlive: Bool { AX.frame(window) != nil }

    /// True when this window is the one its application currently has focused. Used to
    /// tell "the user is working in the pinned window" from "another window of the same
    /// application was raised over it".
    var isFocusedInApp: Bool {
        guard let value = AX.attribute(appElement, kAXFocusedWindowAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        return CFEqual(value, window)
    }

    /// Describes where this pin stands, recomputed by `PinManager` whenever anything
    /// that could change the answer happens.
    struct Placement {
        /// The window belongs to the Space the user is looking at right now.
        var onCurrentSpace: Bool
        /// The user is working in this very window.
        var isActive: Bool
        /// Another pin is also on screen, so this one's mirror has to hold its place in
        /// the stack even while active.
        var hasCompany: Bool
    }

    private var placement = Placement(onCurrentSpace: true, isActive: false, hasCompany: false)

    func apply(_ new: Placement) {
        placement = new
        applyMirroring()
    }

    private func applyMirroring() {
        // A window left behind on another desktop must not leave its mirror or its badge
        // floating over the desktop the user actually switched to.
        guard placement.onCurrentSpace, !isMinimized else {
            isMirroring = false
            mirror.hide()
            marker.hide()
            return
        }

        // While the user is working in the pinned window the real thing is right there,
        // so the mirror is only worth running when it has to outrank another pin's mirror.
        // Dragging always falls back to the real window: a mirror would lag behind it.
        let wanted = !(placement.isActive && (!placement.hasCompany || isDragging))
        isMirroring = wanted

        mirror.setPassThrough(placement.isActive)
        mirror.setLevel(placement.isActive ? WindowMirror.activeLevel : WindowMirror.restingLevel)

        if wanted {
            syncGeometry()
            mirror.show()
        } else {
            mirror.hide()
            syncGeometry()
        }
    }

    /// Brings the real window forward — used when the user clicks the mirror, and when a
    /// pin is removed while the window was still sitting behind other applications.
    func activateRealWindow() {
        guard !isMinimized, placement.onCurrentSpace else { return }
        AX.raise(window)
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
    }

    /// True while the mirror is standing in for the window, i.e. the real one is buried.
    var isShowingMirror: Bool { isMirroring && !isMinimized }

    /// Raises the window within its own application's window stack.
    ///
    /// Only ever safe for a window on the current Space: `AXRaise` on a window that lives
    /// on another desktop drags macOS back to that desktop.
    func raiseWithinApp() {
        guard !isMinimized, placement.onCurrentSpace else { return }
        AX.raise(window)
    }

    func syncGeometry() {
        guard !isMinimized, placement.onCurrentSpace, let frame = AX.frame(window) else {
            marker.hide()
            mirror.hide()
            return
        }
        mirror.setFrame(frame)
        marker.follow(windowFrame: frame)
    }

    func tearDown() {
        endDrag()
        marker.hide()
        mirror.tearDown()
        if let observer {
            for note in Pin.notifications {
                AXObserverRemoveNotification(observer, window, note as CFString)
            }
            AXObserverRemoveNotification(observer, appElement,
                                         kAXFocusedWindowChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  AXObserverGetRunLoopSource(observer),
                                  .defaultMode)
        }
        observer = nil
    }
}

/// C trampoline for `AXObserverCreate`.
private func pinObserverCallback(observer: AXObserver,
                                 element: AXUIElement,
                                 notification: CFString,
                                 refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let pin = Unmanaged<Pin>.fromOpaque(refcon).takeUnretainedValue()
    pin.handle(notification as String)
}
