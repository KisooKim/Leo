import XCTest
@testable import Leo

final class SearchEngineTests: XCTestCase {
    private let dl = Action(keyword: "dl", title: "Downloads", type: .openFolder,
                            path: "~/Downloads", command: nil,
                            urlTemplate: nil, fallbackURL: nil)
    private let doc = Action(keyword: "doc", title: "Docs", type: .openFolder,
                             path: "~/Documents", command: nil,
                             urlTemplate: nil, fallbackURL: nil)
    private let download = Action(keyword: "download", title: "Download Script", type: .runBash,
                                  path: nil, command: "curl example.com",
                                  urlTemplate: nil, fallbackURL: nil)
    private let amazon = Action(keyword: "amazon", title: "Amazon", type: .webSearch,
                                path: nil, command: nil,
                                urlTemplate: "https://amazon.com/s?k={query}",
                                fallbackURL: "https://amazon.com")
    private let google = Action(keyword: "google", title: "Google", type: .webSearch,
                                path: nil, command: nil,
                                urlTemplate: "https://google.com/?q={query}",
                                fallbackURL: nil)

    private func engine(_ actions: Action...) -> SearchEngine {
        SearchEngine(actions: actions, maxResults: 8)
    }

    // MARK: - Plain mode

    func test_emptyQuery_returnsNoResults() {
        let results = engine(dl, doc).search("")
        XCTAssertTrue(results.isEmpty)
    }

    func test_whitespaceOnlyQuery_returnsNoResults() {
        let results = engine(dl, doc).search("   ")
        XCTAssertTrue(results.isEmpty)
    }

    func test_prefixMatch_returnsMatches() {
        let results = engine(dl, doc, download).search("d")
        XCTAssertEqual(results.map(\.displayTitle).sorted(),
                       ["Docs", "Download Script", "Downloads"])
    }

    func test_exactMatch_isSortedFirst() {
        let results = engine(dl, doc, download).search("dl")
        XCTAssertEqual(results.first?.action.keyword, "dl")
    }

    func test_caseInsensitiveMatching() {
        let results = engine(dl, amazon).search("AM")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].action.keyword, "amazon")
    }

    func test_capsAtMaxResults() {
        let many = (0..<20).map {
            Action(keyword: "k\($0)", title: "T\($0)", type: .openFolder,
                   path: "~/", command: nil, urlTemplate: nil, fallbackURL: nil)
        }
        let engine = SearchEngine(actions: many, maxResults: 8)
        XCTAssertEqual(engine.search("k").count, 8)
    }

    // MARK: - Argument mode

    func test_querWithSpace_entersArgumentMode_forWebSearch() {
        let results = engine(amazon, google, dl).search("amazon desk")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].action.keyword, "amazon")
        XCTAssertEqual(results[0].displayTitle, "Search Amazon for 'desk'")
        XCTAssertEqual(results[0].argument, "desk")
    }

    func test_argumentMode_ignoresNonParameterized() {
        let results = engine(dl, amazon).search("dl something")
        XCTAssertTrue(results.isEmpty,
                      "open_folder must not match in argument mode — only web_search does")
    }

    func test_argumentMode_multiWordArgument() {
        let results = engine(amazon).search("amazon desk lamp")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].argument, "desk lamp")
        XCTAssertEqual(results[0].displayTitle, "Search Amazon for 'desk lamp'")
    }

    func test_argumentMode_firstWordMustBeExactMatch() {
        // "amaz desk" should NOT enter argument mode even though 'amaz' prefixes 'amazon'
        let results = engine(amazon).search("amaz desk")
        XCTAssertTrue(results.isEmpty)
    }

    func test_argumentMode_emptyArgument_afterSpace() {
        let results = engine(amazon).search("amazon ")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].argument, "")
        XCTAssertEqual(results[0].displayTitle, "Search Amazon for ''")
    }
}
