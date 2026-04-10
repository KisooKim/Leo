import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Owned components
    private let configURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/leo/actions.json")
    }()

    private lazy var configLoader = ConfigLoader(fileURL: configURL)
    private lazy var configWriter = ConfigWriter(fileURL: configURL)
    private let actionRunner = ActionRunner()
    private let loginItemManager = LoginItemManager()
    private let hotKeyManager = HotKeyManager()
    private lazy var menuBar = MenuBarController(loginItemManager: loginItemManager)

    private lazy var searchWindow = SearchWindow()
    private lazy var searchVC: SearchViewController = {
        let vc = SearchViewController()
        vc.delegate = self
        return vc
    }()
    private var quickAddWindow: QuickAddWindow?

    // Rebuilt on every config reload.
    private var searchEngine = SearchEngine(actions: [])
    private var lastLoadedMTime: Date?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // reinforce LSUIElement behavior

        loadConfig(showWarnings: false)
        setupSearchWindow()

        hotKeyManager.onPress = { [weak self] in self?.toggleSearchWindow() }
        hotKeyManager.register()

        menuBar.onShowLeo      = { [weak self] in self?.showSearchWindow() }
        menuBar.onEditConfig   = { [weak self] in self?.openConfigInEditor() }
        menuBar.onReloadConfig = { [weak self] in self?.loadConfig(showWarnings: true) }
        menuBar.onQuit         = { NSApp.terminate(nil) }
    }

    // MARK: - Config

    private func loadConfig(showWarnings: Bool) {
        do {
            // Capture mtime before and after the read to detect a concurrent edit
            // during load. If they differ, retry once; on second mismatch give up
            // with the first-read state (best we can do without locking).
            let beforeMTime = try configWriter.currentMTime()
            let result = try configLoader.load()
            let afterMTime = try configWriter.currentMTime()

            if beforeMTime != afterMTime {
                // File was written during load. Reload once more to get a consistent view.
                let retryResult = try configLoader.load()
                let retryMTime = try configWriter.currentMTime()
                searchEngine = SearchEngine(actions: builtInActions() + retryResult.actions)
                searchVC.searchEngine = searchEngine
                lastLoadedMTime = retryMTime
                if showWarnings, !retryResult.warnings.isEmpty {
                    presentWarnings(retryResult.warnings)
                }
                return
            }

            searchEngine = SearchEngine(actions: builtInActions() + result.actions)
            searchVC.searchEngine = searchEngine
            lastLoadedMTime = afterMTime
            if showWarnings, !result.warnings.isEmpty {
                presentWarnings(result.warnings)
            }
        } catch {
            presentError(title: "Failed to load config", message: "\(error)")
        }
    }

    private func builtInActions() -> [Action] {
        // Built-ins are represented as Actions with a sentinel type so that the
        // search engine can surface them. They are handled specially in `run(_:)`
        // before the normal ActionRunner dispatch.
        [
            Action(keyword: "reload", title: "Reload config", type: .runBash,
                   path: nil, command: "__builtin_reload",
                   urlTemplate: nil, fallbackURL: nil),
            Action(keyword: "edit",   title: "Edit config", type: .runBash,
                   path: nil, command: "__builtin_edit",
                   urlTemplate: nil, fallbackURL: nil),
            Action(keyword: "add",    title: "Add new action", type: .runBash,
                   path: nil, command: "__builtin_add",
                   urlTemplate: nil, fallbackURL: nil),
            Action(keyword: "quit",   title: "Quit Leo", type: .runBash,
                   path: nil, command: "__builtin_quit",
                   urlTemplate: nil, fallbackURL: nil),
        ]
    }

    private func openConfigInEditor() {
        // Ensure the file exists so `open` has something to target.
        if !FileManager.default.fileExists(atPath: configURL.path) {
            try? FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try? Data("{\"actions\": []}\n".utf8).write(to: configURL)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        }
        NSWorkspace.shared.open(configURL)
    }

    // MARK: - Window toggling

    private func setupSearchWindow() {
        searchVC.searchEngine = searchEngine
        searchWindow.contentViewController = searchVC
    }

    private func showSearchWindow() {
        searchWindow.positionOnActiveScreen()
        searchVC.resetForShow()
        searchWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideSearchWindow() {
        searchWindow.orderOut(nil)
    }

    private func toggleSearchWindow() {
        if searchWindow.isVisible {
            hideSearchWindow()
        } else {
            showSearchWindow()
        }
    }

    // MARK: - Execution

    private func execute(_ result: SearchResult) {
        hideSearchWindow()

        // Built-in commands (identified by sentinel .runBash command).
        if result.action.type == .runBash, let cmd = result.action.command {
            switch cmd {
            case "__builtin_reload":
                loadConfig(showWarnings: true)
                return
            case "__builtin_edit":
                openConfigInEditor()
                return
            case "__builtin_add":
                showQuickAdd()
                return
            case "__builtin_quit":
                NSApp.terminate(nil)
                return
            default:
                break
            }
        }

        do {
            try actionRunner.run(result.action, argument: result.argument)
        } catch {
            presentError(title: "Failed to run action", message: "\(error)")
        }
    }

    // MARK: - Quick Add

    private func showQuickAdd() {
        let window = QuickAddWindow()
        window.onSave = { [weak self] action in
            self?.handleQuickAddSave(action)
        }
        window.onCancel = { [weak self] in
            self?.quickAddWindow = nil
        }
        quickAddWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleQuickAddSave(_ action: Action) {
        do {
            try configWriter.append(action, expectedMTime: lastLoadedMTime)
            loadConfig(showWarnings: false)
        } catch ConfigWriterError.mtimeConflict {
            presentError(
                title: "Config file changed on disk",
                message: "Leo did not overwrite the file. Reload and try again."
            )
            loadConfig(showWarnings: false)
        } catch {
            presentError(title: "Failed to save action", message: "\(error)")
        }
        quickAddWindow = nil
    }

    // MARK: - Alerts

    private func presentWarnings(_ warnings: [String]) {
        let alert = NSAlert()
        alert.messageText = "Config loaded with warnings"
        alert.informativeText = warnings.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - SearchViewControllerDelegate

extension AppDelegate: SearchViewControllerDelegate {
    func searchViewController(_ vc: SearchViewController, didExecute result: SearchResult) {
        execute(result)
    }

    func searchViewControllerDidRequestDismiss(_ vc: SearchViewController) {
        hideSearchWindow()
    }
}
