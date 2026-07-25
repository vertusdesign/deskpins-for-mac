import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var settingsController: SettingsWindowController?
    private var aboutController: AboutWindowController?
    private let manager = PinManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon

        setUpStatusItem()
        manager.onChange = { [weak self] in self?.refreshMenu() }
        manager.onMirrorFailure = { [weak self] reason in self?.flashStatusTitle(reason) }

        HotKeyCenter.shared.action = { [weak self] in self?.pinFrontmost() }
        HotKeyCenter.shared.apply(Settings.shortcut)

        requestMissingPermissions()
        refreshMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.removeAll()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pin.fill",
                                           accessibilityDescription: "DeskPins")
        statusItem.button?.image?.isTemplate = true
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        // The same menu object is refilled rather than replaced: swapping `statusItem.menu`
        // while the menu is being opened glitches the display.
        menu.removeAllItems()

        let pinItem = NSMenuItem(title: L10n.t(.pinFrontmost),
                                 action: #selector(pinFrontmost), keyEquivalent: "")
        pinItem.target = self
        // Showing the global shortcut next to the command is the platform convention.
        if let shortcut = Settings.shortcut {
            pinItem.keyEquivalent = shortcut.menuKeyEquivalent
            pinItem.keyEquivalentModifierMask = shortcut.modifierFlags
        }
        menu.addItem(pinItem)

        menu.addItem(.separator())

        if manager.pins.isEmpty {
            let empty = NSMenuItem(title: L10n.t(.noPinnedWindows), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let header = NSMenuItem(title: L10n.t(.pinnedHeader), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for pin in manager.pins {
                let item = NSMenuItem(title: truncate(pin.name),
                                      action: #selector(unpinFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = pin
                item.state = .on
                item.toolTip = L10n.t(.clickToUnpin)
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let unpinAll = NSMenuItem(title: L10n.t(.unpinAll),
                                      action: #selector(unpinAll), keyEquivalent: "")
            unpinAll.target = self
            menu.addItem(unpinAll)
        }

        menu.addItem(.separator())
        menu.addItem(languageMenuItem())

        let loginItem = NSMenuItem(title: L10n.t(.launchAtLogin),
                                   action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(title: L10n.t(.settings),
                                      action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        if !AX.isTrusted {
            let warn = NSMenuItem(title: "⚠︎ " + L10n.t(.accessibilityNeeded),
                                  action: #selector(openAccessibilitySettings), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }
        if !ScreenCapturePermission.isGranted {
            let warn = NSMenuItem(title: "⚠︎ " + L10n.t(.screenRecordingNeeded),
                                  action: #selector(openScreenRecordingSettings), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }
        if !AX.isTrusted || !ScreenCapturePermission.isGranted {
            menu.addItem(.separator())
        }

        let about = NSMenuItem(title: L10n.t(.about),
                               action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: L10n.t(.quit),
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

    }

    /// Permission state is read while the menu is built, and at launch TCC has often not
    /// caught up yet — which left a stale "permission required" warning sitting in the menu
    /// long after the permission had been granted. Refilling before every display fixes
    /// that, and keeps pinned-window titles current too.
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func languageMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(.language), action: nil, keyEquivalent: "")
        // A globe is the one symbol for "language" that survives not being able to read
        // the menu — the whole point, since this submenu is how you escape a language you
        // do not speak.
        item.image = NSImage(systemSymbolName: "globe", accessibilityDescription: L10n.t(.language))?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        item.image?.isTemplate = true
        let submenu = NSMenu()
        for language in Language.menuOrder {
            let entry = NSMenuItem(title: language.nativeName,
                                   action: #selector(selectLanguage(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = language.rawValue
            entry.state = language == L10n.current ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    private func truncate(_ name: String, limit: Int = 44) -> String {
        name.count <= limit ? name : String(name.prefix(limit - 1)) + "…"
    }

    // MARK: - Actions

    @objc private func pinFrontmost() {
        guard requirePermissions() else { return }
        guard let target = WindowFinder.frontmostTarget() else {
            report(.noWindow)
            return
        }
        report(manager.toggle(target))
    }

    @objc private func unpinFromMenu(_ sender: NSMenuItem) {
        guard let pin = sender.representedObject as? Pin else { return }
        manager.remove(pin, reveal: true)
    }

    @objc private func unpinAll() {
        manager.removeAll()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = Language(rawValue: raw) else { return }
        L10n.select(language)
        settingsController?.localize()
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        let wanted = !LaunchAtLogin.isEnabled
        if !LaunchAtLogin.set(wanted) {
            // The user has switched the item off themselves; only they can re-enable it.
            LaunchAtLogin.openLoginItemsSettings()
        }
        refreshMenu()
    }

    @objc private func openSettings() {
        if settingsController == nil {
            let controller = SettingsWindowController()
            controller.onChange = { [weak self] in self?.refreshMenu() }
            settingsController = controller
        }
        settingsController?.present()
    }

    @objc private func openAbout() {
        if aboutController == nil { aboutController = AboutWindowController() }
        aboutController?.present()
    }

    // MARK: - Permissions

    /// Pinning needs both: Accessibility to track the window, Screen Recording to mirror it.
    ///
    /// Missing permission only triggers the system's own dialog and a warning row in the
    /// menu. An alert of our own would appear on top of the system dialog and hide it.
    private func requirePermissions() -> Bool {
        let missing = requestMissingPermissions()
        guard !missing.isEmpty else { return true }
        refreshMenu()
        flashStatusTitle(missing[0])
        return false
    }

    /// Asks for every permission that is still missing, and returns their names.
    ///
    /// Both are requested, never just the first one. Asking is what puts the app into the
    /// System Settings list: `AXIsProcessTrustedWithOptions` registers it under
    /// Accessibility and `CGRequestScreenCaptureAccess` under Screen Recording. Stopping
    /// after the first missing permission left the app absent from the Screen Recording
    /// list entirely, so a new user had to add it by hand with the "+" button.
    @discardableResult
    private func requestMissingPermissions() -> [String] {
        var missing: [String] = []

        if !AX.isTrusted {
            AX.requestTrust(prompt: true)
            missing.append(L10n.t(.accessibilityNeeded))
        }
        if !ScreenCapturePermission.isGranted {
            ScreenCapturePermission.request()
            missing.append(L10n.t(.screenRecordingNeeded))
        }
        return missing
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func openScreenRecordingSettings() {
        ScreenCapturePermission.openSettings()
    }

    // MARK: - Feedback

    private func report(_ result: PinManager.PinResult) {
        switch result {
        case .pinned, .unpinned:
            refreshMenu()
        case .noWindow:
            flashStatusTitle(L10n.t(.noWindow))
        case .failed:
            flashStatusTitle(L10n.t(.noWindow))
        }
    }

    /// Briefly labels the menu-bar icon instead of throwing up a notification.
    private func flashStatusTitle(_ text: String) {
        statusItem.button?.title = " \(text)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.statusItem.button?.title = ""
        }
    }
}
