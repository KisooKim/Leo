import XCTest
@testable import Leo

final class ActionRunnerTests: XCTestCase {
    // MARK: - Spies

    final class SpyURLOpener: URLOpener {
        var openedURLs: [URL] = []
        func openURL(_ url: URL) { openedURLs.append(url) }
    }

    final class SpyShellRunner: ShellRunning {
        var runCommands: [String] = []
        var throwOnRun: Error?
        func run(command: String) throws {
            if let throwOnRun { throw throwOnRun }
            runCommands.append(command)
        }
    }

    // MARK: - open_folder / open_file

    func test_openFolder_expandsTilde_andOpensURL() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "dl", title: "D", type: .openFolder,
                            path: "~/Downloads", command: nil,
                            urlTemplate: nil, fallbackURL: nil)
        try runner.run(action, argument: nil)

        XCTAssertEqual(opener.openedURLs.count, 1)
        let expected = URL(fileURLWithPath: ("~/Downloads" as NSString).expandingTildeInPath)
        XCTAssertEqual(opener.openedURLs[0], expected)
    }

    func test_openFile_usesSameOpener() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "todo", title: "Todo", type: .openFile,
                            path: "/tmp/todo.md", command: nil,
                            urlTemplate: nil, fallbackURL: nil)
        try runner.run(action, argument: nil)

        XCTAssertEqual(opener.openedURLs, [URL(fileURLWithPath: "/tmp/todo.md")])
    }

    // MARK: - run_bash

    func test_runBash_passesCommandToShellRunner() throws {
        let shell = SpyShellRunner()
        let runner = ActionRunner(urlOpener: SpyURLOpener(), shellRunner: shell)

        let action = Action(keyword: "b", title: "B", type: .runBash,
                            path: nil, command: "echo hi",
                            urlTemplate: nil, fallbackURL: nil)
        try runner.run(action, argument: nil)

        XCTAssertEqual(shell.runCommands, ["echo hi"])
    }

    func test_runBash_propagatesShellError() {
        let shell = SpyShellRunner()
        shell.throwOnRun = NSError(domain: "test", code: 1)
        let runner = ActionRunner(urlOpener: SpyURLOpener(), shellRunner: shell)

        let action = Action(keyword: "b", title: "B", type: .runBash,
                            path: nil, command: "x",
                            urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try runner.run(action, argument: nil))
    }

    // MARK: - web_search

    func test_webSearch_substitutesQuery_andOpensURL() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "amz", title: "A", type: .webSearch,
                            path: nil, command: nil,
                            urlTemplate: "https://amazon.com/s?k={query}",
                            fallbackURL: "https://amazon.com")
        try runner.run(action, argument: "desk")

        XCTAssertEqual(opener.openedURLs,
                       [URL(string: "https://amazon.com/s?k=desk")!])
    }

    func test_webSearch_encodesSpecialCharacters() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "g", title: "G", type: .webSearch,
                            path: nil, command: nil,
                            urlTemplate: "https://google.com/?q={query}",
                            fallbackURL: nil)
        try runner.run(action, argument: "cat & dog")

        XCTAssertEqual(opener.openedURLs.count, 1)
        XCTAssertEqual(opener.openedURLs[0].absoluteString,
                       "https://google.com/?q=cat%20%26%20dog")
    }

    func test_webSearch_emptyArgument_withFallback_opensFallback() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "amz", title: "A", type: .webSearch,
                            path: nil, command: nil,
                            urlTemplate: "https://amazon.com/s?k={query}",
                            fallbackURL: "https://amazon.com")
        try runner.run(action, argument: "")

        XCTAssertEqual(opener.openedURLs, [URL(string: "https://amazon.com")!])
    }

    func test_webSearch_emptyArgument_withoutFallback_isNoOp() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "g", title: "G", type: .webSearch,
                            path: nil, command: nil,
                            urlTemplate: "https://google.com/?q={query}",
                            fallbackURL: nil)
        try runner.run(action, argument: "")

        XCTAssertTrue(opener.openedURLs.isEmpty)
    }

    // MARK: - Error guards

    func test_openFolder_missingPath_throws() {
        let runner = ActionRunner(urlOpener: SpyURLOpener(), shellRunner: SpyShellRunner())
        let action = Action(keyword: "x", title: "X", type: .openFolder,
                            path: nil, command: nil, urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try runner.run(action, argument: nil)) { error in
            XCTAssertEqual(error as? ActionRunnerError, .missingPath)
        }
    }

    func test_runBash_missingCommand_throws() {
        let runner = ActionRunner(urlOpener: SpyURLOpener(), shellRunner: SpyShellRunner())
        let action = Action(keyword: "x", title: "X", type: .runBash,
                            path: nil, command: nil, urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try runner.run(action, argument: nil)) { error in
            XCTAssertEqual(error as? ActionRunnerError, .missingCommand)
        }
    }

    func test_webSearch_missingTemplate_throws() {
        let runner = ActionRunner(urlOpener: SpyURLOpener(), shellRunner: SpyShellRunner())
        let action = Action(keyword: "x", title: "X", type: .webSearch,
                            path: nil, command: nil, urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try runner.run(action, argument: "query")) { error in
            XCTAssertEqual(error as? ActionRunnerError, .missingURLTemplate)
        }
    }

    func test_webSearch_nilArgument_treatedAsEmpty() throws {
        let opener = SpyURLOpener()
        let runner = ActionRunner(urlOpener: opener, shellRunner: SpyShellRunner())

        let action = Action(keyword: "amz", title: "A", type: .webSearch,
                            path: nil, command: nil,
                            urlTemplate: "https://amazon.com/s?k={query}",
                            fallbackURL: "https://amazon.com")
        try runner.run(action, argument: nil)

        XCTAssertEqual(opener.openedURLs, [URL(string: "https://amazon.com")!])
    }
}
