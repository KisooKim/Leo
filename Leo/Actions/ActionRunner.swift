import AppKit
import Foundation

// MARK: - Protocols (for testability)

protocol URLOpener {
    func openURL(_ url: URL)
}

protocol ShellRunning {
    func run(command: String) throws
}

// MARK: - Production implementations

struct WorkspaceURLOpener: URLOpener {
    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

struct ZshRunner: ShellRunning {
    func run(command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        try process.run()
        // Fire-and-forget: do not wait, do not capture stdout/stderr.
    }
}

// MARK: - Errors

enum ActionRunnerError: Error, Equatable {
    case missingPath
    case missingCommand
    case missingURLTemplate
    case invalidURL(String)
    case encodingFailed
}

// MARK: - Runner

final class ActionRunner {
    private let urlOpener: URLOpener
    private let shellRunner: ShellRunning

    init(urlOpener: URLOpener = WorkspaceURLOpener(),
         shellRunner: ShellRunning = ZshRunner()) {
        self.urlOpener = urlOpener
        self.shellRunner = shellRunner
    }

    func run(_ action: Action, argument: String?) throws {
        switch action.type {
        case .openFolder, .openFile:
            try runOpen(action)
        case .runBash:
            try runBash(action)
        case .webSearch:
            try runWebSearch(action, argument: argument)
        }
    }

    // MARK: - Handlers

    private func runOpen(_ action: Action) throws {
        guard let path = action.path, !path.isEmpty else {
            throw ActionRunnerError.missingPath
        }
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        urlOpener.openURL(url)
    }

    private func runBash(_ action: Action) throws {
        guard let command = action.command, !command.isEmpty else {
            throw ActionRunnerError.missingCommand
        }
        try shellRunner.run(command: command)
    }

    private func runWebSearch(_ action: Action, argument: String?) throws {
        guard let template = action.urlTemplate, !template.isEmpty else {
            throw ActionRunnerError.missingURLTemplate
        }

        let trimmed = (argument ?? "").trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            if let fallback = action.fallbackURL, let url = URL(string: fallback) {
                urlOpener.openURL(url)
            }
            return
        }

        // Encode so &, +, =, ?, # in the argument don't corrupt the query string.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        // addingPercentEncoding returns nil only for malformed UTF-16 (lone surrogates).
        // This is unreachable in practice from user-typed text, but the guard stays
        // for defensive correctness.
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw ActionRunnerError.encodingFailed
        }

        let raw = template.replacingOccurrences(of: "{query}", with: encoded)
        guard let url = URL(string: raw) else {
            throw ActionRunnerError.invalidURL(raw)
        }
        urlOpener.openURL(url)
    }
}
