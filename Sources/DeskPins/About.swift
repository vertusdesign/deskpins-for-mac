import AppKit

/// Every outbound link the app offers, in one place.
enum Links {
    static let repository = URL(string: "https://github.com/vertusdesign/deskpins-for-mac")!
    static let terms = URL(string: "https://github.com/vertusdesign/deskpins-for-mac/blob/main/TERMS.md")!
    static let privacy = URL(string: "https://github.com/vertusdesign/deskpins-for-mac/blob/main/PRIVACY.md")!
    static let disclaimer = URL(string: "https://github.com/vertusdesign/deskpins-for-mac/blob/main/DISCLAIMER.md")!
    /// The Windows original this project is a tribute to — not a port, and not related code.
    static let originalDeskPins = URL(string: "https://deskpins.com/")!
}

/// Where the app's own identity comes from, so the bundle stays the single source of truth.
enum AppInfo {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "DeskPins for Mac"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Release stage shown next to the version, e.g. "alpha".
    static var stage: String? {
        Bundle.main.object(forInfoDictionaryKey: "DPReleaseStage") as? String
    }

    static var versionLine: String {
        guard let stage, !stage.isEmpty else { return "Version \(version)" }
        return "Version \(version) (\(stage))"
    }

    static let copyright = "MIT License · © 2026 DeskPins for Mac contributors"
}

final class AboutWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false
        self.init(window: window)
        build()
    }

    /// Rebuilt from scratch on every open so a language change is picked up.
    private func build() {
        guard let window else { return }
        window.title = L10n.t(.about)

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let name = label(AppInfo.displayName, font: .systemFont(ofSize: 18, weight: .semibold))
        let version = label(AppInfo.versionLine,
                            font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                            color: .secondaryLabelColor)
        let tagline = label(L10n.t(.aboutTagline), font: .systemFont(ofSize: NSFont.systemFontSize))
        let alphaNotice = label(L10n.t(.aboutAlphaNotice),
                                font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                                color: .secondaryLabelColor)

        let inspired = LinkButton(title: L10n.t(.aboutInspiredBy), url: Links.originalDeskPins)

        let linkRow = NSStackView(views: [
            LinkButton(title: L10n.t(.aboutSource), url: Links.repository),
            LinkButton(title: L10n.t(.aboutTerms), url: Links.terms),
            LinkButton(title: L10n.t(.aboutPrivacy), url: Links.privacy),
            LinkButton(title: L10n.t(.aboutDisclaimer), url: Links.disclaimer),
        ])
        linkRow.orientation = .horizontal
        linkRow.spacing = 14
        linkRow.alignment = .centerY

        let copyright = label(AppInfo.copyright,
                              font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                              color: .tertiaryLabelColor)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 320).isActive = true

        let stack = NSStackView(views: [
            icon, name, version, tagline, alphaNotice, divider, inspired, linkRow, copyright,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(4, after: name)
        stack.setCustomSpacing(16, after: version)
        stack.setCustomSpacing(18, after: alphaNotice)
        stack.setCustomSpacing(18, after: divider)
        stack.setCustomSpacing(16, after: linkRow)
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.setContentSize(stack.fittingSize)
    }

    func present() {
        build()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func label(_ text: String,
                       font: NSFont,
                       color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.alignment = .center
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 3
        field.preferredMaxLayoutWidth = 380
        return field
    }
}

/// A text-only button that looks like a link and opens a URL.
private final class LinkButton: NSButton {
    private let url: URL

    init(title: String, url: URL) {
        self.url = url
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .inline
        setButtonType(.momentaryChange)
        target = self
        action = #selector(open)
        toolTip = url.absoluteString

        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.linkColor,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func open() { NSWorkspace.shared.open(url) }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
