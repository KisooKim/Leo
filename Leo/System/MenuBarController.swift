import AppKit

/// Owns the NSStatusItem and its menu. Wire callbacks in AppDelegate.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let loginItemManager: LoginItemManager

    var onShowLeo: (() -> Void)?
    var onEditConfig: (() -> Void)?
    var onReloadConfig: (() -> Void)?
    var onQuit: (() -> Void)?

    init(loginItemManager: LoginItemManager) {
        self.loginItemManager = loginItemManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        rebuildMenu()
    }

    private func configureButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkle.magnifyingglass",
                                   accessibilityDescription: "Leo")
            button.image?.isTemplate = true
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let show = NSMenuItem(title: "Show Leo (⌥Space)",
                              action: #selector(showLeoClicked),
                              keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        menu.addItem(.separator())

        let edit = NSMenuItem(title: "Edit Config",
                              action: #selector(editConfigClicked),
                              keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)

        let reload = NSMenuItem(title: "Reload Config",
                                action: #selector(reloadConfigClicked),
                                keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)

        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin),
                                       keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Leo",
                              action: #selector(quitClicked),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func showLeoClicked()     { onShowLeo?() }
    @objc private func editConfigClicked()  { onEditConfig?() }
    @objc private func reloadConfigClicked(){ onReloadConfig?() }
    @objc private func quitClicked()        { onQuit?() }

    @objc private func toggleLaunchAtLogin() {
        do {
            try loginItemManager.toggle()
            rebuildMenu() // refresh checkmark
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to toggle Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
