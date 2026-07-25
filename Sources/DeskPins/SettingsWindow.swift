import AppKit
import Carbon.HIToolbox

/// The single settings window: the global shortcut and the login item.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private let recorder = ShortcutRecorderView()
    private let hintLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let loginCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let restoreDefaultButton = NSButton(title: "", target: nil, action: nil)

    /// Called whenever a setting changes, so the menu can be rebuilt.
    var onChange: (() -> Void)?

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 206),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
        buildLayout()
        localize()
    }

    // MARK: - Layout

    private func buildLayout() {
        guard let content = window?.contentView else { return }

        shortcutLabel.alignment = .right
        shortcutLabel.textColor = .labelColor

        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2

        recorder.onChange = { [weak self] shortcut in
            Settings.shortcut = shortcut
            HotKeyCenter.shared.apply(shortcut)
            self?.updateRestoreButton()
            self?.onChange?()
        }

        restoreDefaultButton.bezelStyle = .rounded
        restoreDefaultButton.controlSize = .small
        restoreDefaultButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        restoreDefaultButton.target = self
        restoreDefaultButton.action = #selector(restoreDefaultShortcut)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLoginItem(_:))

        for view in [shortcutLabel, recorder, hintLabel, restoreDefaultButton, loginCheckbox] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            shortcutLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            shortcutLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            shortcutLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 190),

            recorder.leadingAnchor.constraint(equalTo: shortcutLabel.trailingAnchor, constant: 10),
            recorder.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            recorder.centerYAnchor.constraint(equalTo: shortcutLabel.centerYAnchor),
            recorder.heightAnchor.constraint(equalToConstant: 26),

            hintLabel.leadingAnchor.constraint(equalTo: recorder.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            hintLabel.topAnchor.constraint(equalTo: recorder.bottomAnchor, constant: 8),

            restoreDefaultButton.leadingAnchor.constraint(equalTo: recorder.leadingAnchor),
            restoreDefaultButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 10),

            loginCheckbox.leadingAnchor.constraint(equalTo: recorder.leadingAnchor),
            loginCheckbox.topAnchor.constraint(equalTo: restoreDefaultButton.bottomAnchor,
                                               constant: 20),
            loginCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor,
                                                    constant: -20),
        ])
    }

    // MARK: - Contents

    /// Re-reads every string and value; called on open and whenever the language changes.
    func localize() {
        window?.title = L10n.t(.settingsWindowTitle)
        shortcutLabel.stringValue = L10n.t(.shortcutTitle)
        hintLabel.stringValue = L10n.t(.shortcutHint)
        loginCheckbox.title = L10n.t(.launchAtLogin)
        restoreDefaultButton.title = L10n.t(.shortcutRestoreDefault)
        recorder.shortcut = Settings.shortcut
        recorder.needsDisplay = true
        loginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        updateRestoreButton()
    }

    /// Stays in place but greys out while the default is already in use, so the row
    /// beneath the recorder never jumps around.
    private func updateRestoreButton() {
        restoreDefaultButton.isEnabled = Settings.shortcut != Shortcut.fallback
    }

    @objc private func restoreDefaultShortcut() {
        Settings.shortcut = .fallback
        HotKeyCenter.shared.apply(.fallback)
        recorder.shortcut = .fallback
        recorder.needsDisplay = true
        updateRestoreButton()
        onChange?()
    }

    func present() {
        localize()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLoginItem(_ sender: NSButton) {
        let wanted = sender.state == .on
        if !LaunchAtLogin.set(wanted) {
            // Registration is refused while the user has the item disabled themselves;
            // send them where they can change it.
            LaunchAtLogin.openLoginItemsSettings()
        }
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
        onChange?()
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        recorder.cancelRecording()
    }

    func windowWillClose(_ notification: Notification) {
        recorder.cancelRecording()
    }
}

/// A control that captures the next key combination the user presses.
///
/// Follows the platform convention: click to arm, ⎋ cancels, ⌫ clears the shortcut, and
/// a combination without modifiers is rejected because it could not be registered globally.
final class ShortcutRecorderView: NSView {

    var shortcut: Shortcut?
    var onChange: ((Shortcut?) -> Void)?

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    // MARK: - Recording

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        HotKeyCenter.shared.suspend()   // so the current shortcut can be re-recorded
        needsDisplay = true
    }

    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        HotKeyCenter.shared.resume()
        needsDisplay = true
    }

    private func finish(with shortcut: Shortcut?) {
        self.shortcut = shortcut
        isRecording = false
        onChange?(shortcut)
        HotKeyCenter.shared.resume()
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        cancelRecording()
        return true
    }

    /// Key equivalents are consumed before `keyDown`, which is exactly where combinations
    /// like ⌘Q arrive — so recording has to happen here to capture them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handle(event)
    }

    override func flagsChanged(with event: NSEvent) {
        if isRecording { needsDisplay = true }
        super.flagsChanged(with: event)
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            cancelRecording()
        case kVK_Delete, kVK_ForwardDelete:
            finish(with: nil)                       // ⌫ switches the shortcut off
        default:
            guard let recorded = Shortcut(event: event) else {
                NSSound.beep()                      // no modifier — not registrable
                return
            }
            finish(with: recorded)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let box = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6)

        NSColor.textBackgroundColor.setFill()
        path.fill()

        if isRecording {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
        }
        path.stroke()

        let text: String
        let color: NSColor
        if isRecording {
            text = L10n.t(.shortcutPress)
            color = .secondaryLabelColor
        } else if let shortcut {
            text = shortcut.displayString
            color = .labelColor
        } else {
            text = "\(L10n.t(.shortcutNone)) — \(L10n.t(.shortcutRecord))"
            color = .secondaryLabelColor
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2),
                  withAttributes: attributes)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
