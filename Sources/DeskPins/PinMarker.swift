import AppKit

/// The little green pin drawn over a pinned window's title bar.
///
/// A non-activating panel: showing it never steals focus from the window it decorates.
final class PinMarker {
    static let size = CGSize(width: 22, height: 22)

    /// Distance of the badge from the window's top-right corner, before the nudge below.
    private static let baseInset = (right: CGFloat(8), top: CGFloat(5))
    /// Requested adjustment: 14pt right, 11pt up (screen coordinates: x +14, y −11).
    private static let nudge = (x: CGFloat(14), y: CGFloat(11))

    private let panel: NSPanel
    private let onClick: () -> Void

    /// Latest known window frame, so the badge can be put back in the right place after
    /// a drag without asking the Accessibility API again.
    private var lastFrame: CGRect?
    /// True while the user is dragging the window and the badge is faded out.
    private var isSuppressed = false
    private var isFading = false

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: PinMarker.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Just above every mirror and nothing more. `.screenSaver` would put a badge over
        // system UI and the screen saver, which no ordinary app has any business doing.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        panel.ignoresMouseEvents = false
        // `.transient` hides the badge in Mission Control together with its mirror.
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.animationBehavior = .none     // the fades below are ours to control
        panel.isReleasedWhenClosed = false

        let view = MarkerView(frame: NSRect(origin: .zero, size: PinMarker.size))
        view.onClick = onClick
        panel.contentView = view
    }

    /// Places the marker in the top-right of a window frame given in Quartz coordinates.
    func follow(windowFrame quartz: CGRect) {
        lastFrame = quartz
        // While the window is being dragged the badge is hidden, so there is nothing to
        // move — it is repositioned once, when the drag ends.
        guard !isSuppressed else { return }
        place(quartz)
        if !panel.isVisible {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    private func place(_ quartz: CGRect) {
        let cocoa = Coord.cocoa(from: quartz)
        let origin = NSPoint(
            x: cocoa.maxX - PinMarker.size.width - PinMarker.baseInset.right + PinMarker.nudge.x,
            y: cocoa.maxY - PinMarker.size.height - PinMarker.baseInset.top + PinMarker.nudge.y)
        panel.setFrameOrigin(origin)
    }

    func hide() {
        isSuppressed = false
        panel.orderOut(nil)
    }

    // MARK: - Drag suppression

    /// Fades the badge out for the duration of a window drag, so it never chases the
    /// window frame by frame.
    func suppressForDrag() {
        guard !isSuppressed else { return }
        isSuppressed = true
        guard panel.isVisible else { return }

        isFading = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.isFading = false
            // A drag that ended mid-fade must not leave the badge hidden.
            if self.isSuppressed { self.panel.orderOut(nil) } else { self.restore() }
        }
    }

    /// Puts the badge back at the window's new corner once the drag is over.
    func endDragSuppression() {
        guard isSuppressed else { return }
        isSuppressed = false
        guard !isFading else { return }   // the fade-out completion will restore it
        restore()
    }

    private func restore() {
        guard let lastFrame else { return }
        place(lastFrame)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private final class MarkerView: NSView {
        var onClick: (() -> Void)?

        /// A fresh-green badge: light at the top, deeper at the bottom, so the white pin
        /// keeps enough contrast against the lighter half.
        private static let gradient = NSGradient(
            starting: NSColor(srgbRed: 0.64, green: 0.86, blue: 0.38, alpha: 1),
            ending:   NSColor(srgbRed: 0.36, green: 0.68, blue: 0.20, alpha: 1))

        override func draw(_ dirtyRect: NSRect) {
            let inset = bounds.insetBy(dx: 1, dy: 1)

            NSColor.black.withAlphaComponent(0.24).setFill()
            NSBezierPath(ovalIn: inset.offsetBy(dx: 0, dy: -1)).fill()

            let circle = NSBezierPath(ovalIn: inset)
            MarkerView.gradient?.draw(in: circle, angle: -90)

            // A soft rim keeps the badge readable on light window content too.
            NSColor.white.withAlphaComponent(0.55).setStroke()
            circle.lineWidth = 1
            circle.stroke()

            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            if let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                pin.draw(in: NSRect(
                    x: bounds.midX - pin.size.width / 2,
                    y: bounds.midY - pin.size.height / 2,
                    width: pin.size.width, height: pin.size.height))
            }
        }

        override func mouseDown(with event: NSEvent) { onClick?() }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}
