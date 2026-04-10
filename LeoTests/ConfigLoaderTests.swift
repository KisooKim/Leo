import XCTest
@testable import Leo

final class ConfigLoaderTests: XCTestCase {
    private var tmpDir: URL!
    private var configURL: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("leo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        configURL = tmpDir.appendingPathComponent("actions.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func write(_ json: String) throws {
        try json.data(using: .utf8)!.write(to: configURL)
        // Ensure predictable baseline permissions (0600) so tests that don't
        // explicitly set permissions don't see a permission warning.
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                              ofItemAtPath: configURL.path)
    }

    func test_missingFile_returnsEmptyList() throws {
        let loader = ConfigLoader(fileURL: configURL)
        let result = try loader.load()
        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func test_validFile_returnsAllActions() throws {
        try write("""
        {"actions": [
          {"keyword": "dl", "title": "Downloads", "type": "open_folder", "path": "~/Downloads"},
          {"keyword": "g", "title": "Google", "type": "web_search",
           "url_template": "https://google.com/?q={query}"}
        ]}
        """)
        let loader = ConfigLoader(fileURL: configURL)
        let result = try loader.load()
        XCTAssertEqual(result.actions.count, 2)
        XCTAssertEqual(result.actions[0].keyword, "dl")
        XCTAssertEqual(result.actions[1].type, .webSearch)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func test_malformedEntry_isDroppedWithWarning() throws {
        try write("""
        {"actions": [
          {"keyword": "good", "title": "Good", "type": "open_folder", "path": "~/"},
          {"keyword": "bad", "title": "Bad", "type": "open_folder"}
        ]}
        """)
        let loader = ConfigLoader(fileURL: configURL)
        let result = try loader.load()
        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.actions[0].keyword, "good")
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertTrue(result.warnings[0].contains("bad"))
    }

    func test_malformedJSON_throws() throws {
        try write("not json at all")
        let loader = ConfigLoader(fileURL: configURL)
        XCTAssertThrowsError(try loader.load())
    }

    func test_permissionLooserThan0600_producesWarning() throws {
        try write("""
        {"actions": []}
        """)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: configURL.path)
        let loader = ConfigLoader(fileURL: configURL)
        let result = try loader.load()
        XCTAssertTrue(result.warnings.contains { $0.contains("permission") || $0.contains("0600") })
    }

    func test_permissionExactly0600_noWarning() throws {
        try write("""
        {"actions": []}
        """)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        let loader = ConfigLoader(fileURL: configURL)
        let result = try loader.load()
        XCTAssertTrue(result.warnings.isEmpty)
    }
}
