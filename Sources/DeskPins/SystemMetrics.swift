import AppKit

/// Values read from the running system's theme rather than hard-coded.
enum SystemMetrics {

    /// The corner radius macOS currently uses for ordinary windows.
    ///
    /// AppKit exposes no public accessor, so we ask a throwaway titled window for the
    /// radius of its frame view — the same value the system draws real windows with,
    /// so the mirror keeps matching after an OS update that changes the look.
    /// Every step is guarded: if the key ever disappears we fall back to the radius
    /// that shipped with the current major version.
    static let windowCornerRadius: CGFloat = {
        let probe = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 64, height: 64),
                             styleMask: [.titled, .closable],
                             backing: .buffered,
                             defer: true)
        // NSWindow created in code defaults to isReleasedWhenClosed = true, so close()
        // would release a window ARC still owns and the process dies on the next pool pop.
        probe.isReleasedWhenClosed = false
        defer { probe.close() }

        guard let frameView = probe.contentView?.superview,
              frameView.responds(to: NSSelectorFromString("cornerRadius")),
              let radius = frameView.value(forKey: "cornerRadius") as? CGFloat,
              radius > 0, radius < 64
        else { return fallbackCornerRadius }

        return radius
    }()

    private static var fallbackCornerRadius: CGFloat {
        if #available(macOS 26.0, *) { return 16 }   // Tahoe rounded everything further
        return 10                                     // Big Sur … Sequoia
    }
}
