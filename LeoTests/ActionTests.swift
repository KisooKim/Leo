import XCTest
@testable import Leo

final class ActionTests: XCTestCase {
    private func decode(_ json: String) throws -> Action {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Action.self, from: Data(json.utf8))
    }

    func test_decode_openFolder() throws {
        let action = try decode("""
        {"keyword": "dl", "title": "Downloads", "type": "open_folder", "path": "~/Downloads"}
        """)
        XCTAssertEqual(action.keyword, "dl")
        XCTAssertEqual(action.title, "Downloads")
        XCTAssertEqual(action.type, .openFolder)
        XCTAssertEqual(action.path, "~/Downloads")
        XCTAssertNil(action.command)
        XCTAssertNil(action.urlTemplate)
    }

    func test_decode_runBash() throws {
        let action = try decode("""
        {"keyword": "backup", "title": "Backup", "type": "run_bash", "command": "rsync -a a b"}
        """)
        XCTAssertEqual(action.type, .runBash)
        XCTAssertEqual(action.command, "rsync -a a b")
    }

    func test_decode_webSearch_withFallback() throws {
        let action = try decode("""
        {"keyword": "amazon", "title": "Amazon", "type": "web_search",
         "url_template": "https://www.amazon.com/s?k={query}",
         "fallback_url": "https://www.amazon.com"}
        """)
        XCTAssertEqual(action.type, .webSearch)
        XCTAssertEqual(action.urlTemplate, "https://www.amazon.com/s?k={query}")
        XCTAssertEqual(action.fallbackURL, "https://www.amazon.com")
    }

    func test_decode_unknownType_throws() {
        XCTAssertThrowsError(try decode("""
        {"keyword": "x", "title": "X", "type": "fly_to_moon"}
        """))
    }

    func test_validate_openFolder_withoutPath_throws() {
        let action = Action(keyword: "dl", title: "Downloads", type: .openFolder,
                            path: nil, command: nil, urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try action.validate()) { error in
            XCTAssertEqual(error as? ActionValidationError, .missingPath)
        }
    }

    func test_validate_runBash_withoutCommand_throws() {
        let action = Action(keyword: "b", title: "B", type: .runBash,
                            path: nil, command: "", urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try action.validate()) { error in
            XCTAssertEqual(error as? ActionValidationError, .missingCommand)
        }
    }

    func test_validate_webSearch_withoutQueryPlaceholder_throws() {
        let action = Action(keyword: "g", title: "G", type: .webSearch,
                            path: nil, command: nil,
                            urlTemplate: "https://google.com/search",
                            fallbackURL: nil)
        XCTAssertThrowsError(try action.validate()) { error in
            XCTAssertEqual(error as? ActionValidationError, .missingQueryPlaceholder)
        }
    }

    func test_validate_emptyKeyword_throws() {
        let action = Action(keyword: "  ", title: "X", type: .openFolder,
                            path: "~/", command: nil, urlTemplate: nil, fallbackURL: nil)
        XCTAssertThrowsError(try action.validate()) { error in
            XCTAssertEqual(error as? ActionValidationError, .emptyKeyword)
        }
    }

    func test_acceptsArgument_only_webSearch() {
        let web = Action(keyword: "g", title: "G", type: .webSearch,
                         path: nil, command: nil,
                         urlTemplate: "https://x/{query}", fallbackURL: nil)
        let folder = Action(keyword: "d", title: "D", type: .openFolder,
                            path: "~/", command: nil, urlTemplate: nil, fallbackURL: nil)
        XCTAssertTrue(web.acceptsArgument)
        XCTAssertFalse(folder.acceptsArgument)
    }
}
