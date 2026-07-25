import AppKit
import ScreenCaptureKit
import CoreMedia

/// A live copy of another application's window, drawn in a panel we own.
///
/// This is the only way to get genuine "always on top" out of public macOS APIs. The z-order
/// of ordinary windows is application-centric — the active app's windows sit above every
/// other app's — so no amount of `AXRaise` can lift a background window above the app you
/// are working in. A window we own, however, obeys `NSWindow.level`, so we float our own
/// panel and stream the target window's pixels into it.
///
/// The mirror is only alive while the user is not working in the pinned window; the moment
/// that window becomes the focused one, the real thing is right there to interact with and
/// the capture is shut down. All mirrors share one level — raising the active one above the
/// others hid those windows behind it and made clicks ping-pong between the two.
final class WindowMirror: NSObject, SCStreamOutput, SCStreamDelegate {

    private let windowID: CGWindowID
    private let panel: NSPanel
    private let mirrorLayer = CALayer()
    private let captureQueue = DispatchQueue(label: "com.deskpins.capture")

    private var stream: SCStream?
    private var retainedBuffer: CVPixelBuffer?   // keeps the IOSurface alive while displayed
    private var isStarting = false
    private var wantsCapture = false
    private var frameQuartz: CGRect = .zero
    private var restartWork: DispatchWorkItem?

    /// Called when the user clicks the mirror — the real window should come forward.
    var onClick: (() -> Void)?
    /// Called when capture cannot run (permission revoked, window gone).
    var onFailure: ((String) -> Void)?

    init(windowID: CGWindowID) {
        self.windowID = windowID

        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        panel.isOpaque = false          // required for the rounded corners to punch through
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating              // above ordinary windows, below the pin marker
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        // `.transient` is what hides the mirror in Mission Control and Exposé; `.stationary`
        // would do the opposite and keep it floating over them.
        panel.collectionBehavior = [.canJoinAllSpaces, .transient,
                                    .ignoresCycle, .fullScreenAuxiliary]
        // Panels animate themselves into view by default, which reads as the mirror
        // "popping" open in place of the real window.
        panel.animationBehavior = .none
        super.init()

        mirrorLayer.contentsGravity = .resize
        mirrorLayer.backgroundColor = NSColor.windowBackgroundColor.cgColor
        // Match the shape macOS gives real windows, radius read from the running theme.
        mirrorLayer.cornerRadius = SystemMetrics.windowCornerRadius
        mirrorLayer.cornerCurve = .continuous      // the squircle AppKit itself draws
        mirrorLayer.masksToBounds = true

        let view = MirrorView()
        view.wantsLayer = true
        view.layer = mirrorLayer
        view.onClick = { [weak self] in self?.onClick?() }
        panel.contentView = view
    }

    // MARK: - Geometry

    /// Keeps the panel exactly over the window it mirrors. `quartz` is in Quartz coordinates.
    func setFrame(_ quartz: CGRect) {
        let sizeChanged = abs(quartz.width - frameQuartz.width) > 1
                       || abs(quartz.height - frameQuartz.height) > 1
        frameQuartz = quartz
        panel.setFrame(Coord.cocoa(from: quartz), display: false)

        if sizeChanged, wantsCapture { scheduleRestart() }
    }

    // MARK: - Capture lifecycle

    func show() {
        guard !wantsCapture else { return }
        wantsCapture = true
        panel.orderFrontRegardless()
        panel.invalidateShadow()        // so the shadow hugs the rounded corners
        startCapture()
    }

    func hide() {
        wantsCapture = false
        restartWork?.cancel()
        panel.orderOut(nil)
        stopCapture()
    }

    func tearDown() {
        hide()
        panel.close()
    }

    private func startCapture() {
        guard !isStarting, stream == nil, frameQuartz.width > 0 else { return }
        isStarting = true

        let scale = screenScale(for: frameQuartz)
        let width = max(2, Int(frameQuartz.width * scale))
        let height = max(2, Int(frameQuartz.height * scale))

        Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: false)
                guard let scWindow = content.windows.first(where: { $0.windowID == self.windowID }) else {
                    await self.finishStart(nil, error: "окно больше не существует")
                    return
                }

                let config = SCStreamConfiguration()
                config.width = width
                config.height = height
                config.scalesToFit = true
                config.showsCursor = false
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.queueDepth = 3
                // ScreenCaptureKit only delivers a frame when the content actually changes,
                // so a static window costs nothing; this just caps the rate when it does.
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                // macOS overlays a "this window is being captured" pill on the window it
                // is streaming. Excluding child windows is the only lever the framework
                // offers against it. Trade-off: sheets and popovers belonging to the
                // pinned window stop showing up in the mirror too.
                if #available(macOS 14.2, *) { config.includeChildWindows = false }

                let filter = SCContentFilter(desktopIndependentWindow: scWindow)
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen,
                                           sampleHandlerQueue: self.captureQueue)
                try await stream.startCapture()
                await self.finishStart(stream, error: nil)
            } catch {
                await self.finishStart(nil, error: error.localizedDescription)
            }
        }
    }

    @MainActor
    private func finishStart(_ started: SCStream?, error: String?) {
        isStarting = false
        mirrorLayer.contentsScale = screenScale(for: frameQuartz)

        guard wantsCapture else {          // hidden again while we were starting up
            started?.stopCapture { _ in }
            return
        }
        if let started {
            stream = started
        } else if let error {
            onFailure?(error)
        }
    }

    private func stopCapture() {
        guard let stream else { return }
        self.stream = nil
        stream.stopCapture { _ in }
    }

    /// A resize invalidates the stream's fixed output size; rebuild it, debounced.
    private func scheduleRestart() {
        restartWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.wantsCapture else { return }
            self.stopCapture()
            self.startCapture()
        }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func screenScale(for quartz: CGRect) -> CGFloat {
        let cocoa = Coord.cocoa(from: quartz)
        let screen = NSScreen.screens.first { $0.frame.intersects(cocoa) } ?? NSScreen.main
        return screen?.backingScaleFactor ?? 2
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let pixels = CMSampleBufferGetImageBuffer(buffer),
              isComplete(buffer)
        else { return }

        // Handing the IOSurface straight to the layer keeps this zero-copy: no CIContext,
        // no CGImage, no per-frame allocation.
        guard let surface = CVPixelBufferGetIOSurface(pixels)?.takeUnretainedValue() else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsCapture else { return }
            self.retainedBuffer = pixels
            self.mirrorLayer.contents = surface
        }
    }

    /// Skips the `.idle`/`.blank` frames ScreenCaptureKit emits when nothing changed.
    private func isComplete(_ buffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
                buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw)
        else { return false }
        return status == .complete
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stream = nil
            if self.wantsCapture { self.onFailure?(error.localizedDescription) }
        }
    }

    // MARK: - Click target

    private final class MirrorView: NSView {
        var onClick: (() -> Void)?
        override func mouseDown(with event: NSEvent) { onClick?() }
        override var mouseDownCanMoveWindow: Bool { false }
    }
}

/// Screen Recording permission — required before any window can be mirrored.
enum ScreenCapturePermission {
    /// `CGPreflightScreenCaptureAccess` caches its answer for the lifetime of the process,
    /// so once it has said no it keeps saying no even after the user grants access. A
    /// successful ScreenCaptureKit query is proof to the contrary, and is remembered here
    /// so granting the permission does not require quitting the app.
    private static var confirmedGranted = false

    static var isGranted: Bool {
        if confirmedGranted { return true }
        if CGPreflightScreenCaptureAccess() {
            confirmedGranted = true
            return true
        }
        return false
    }

    /// Asks for access, and registers the app in the Screen Recording list as a side effect.
    ///
    /// Both routes are used deliberately. `CGRequestScreenCaptureAccess` is the documented
    /// request, but a ScreenCaptureKit query is what reliably registers the app and, unlike
    /// the preflight call, reports the permission's live state rather than a cached one.
    static func request(completion: ((Bool) -> Void)? = nil) {
        _ = CGRequestScreenCaptureAccess()
        Task { @MainActor in
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true)
                confirmedGranted = true
                completion?(true)
            } catch {
                completion?(false)
            }
        }
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
