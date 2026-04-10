import XCTest
@testable import Leo

final class ConfigWriterTests: XCTestCase {
    private var tmpDir: URL!
    private var configURL: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("leo-writer-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        configURL = tmpDir.appendingPathComponent("actions.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func read() throws -> [Action] {
        let loader = ConfigLoader(fileURL: configURL)
        return try loader.load().actions
    }

    func test_appendsToExistingFile() throws {
        try """
        {"actions": [
          {"keyword": "dl", "title": "Downloads", "type": "open_folder", "path": "~/Downloads"}
        ]}
        """.data(using: .utf8)!.write(to: configURL)
        // Match the 0600 umask convention used elsewhere
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)

        let writer = ConfigWriter(fileURL: configURL)
        let newAction = Action(keyword: "todo", title: "Todo", type: .openFile,
                               path: "~/todo.md", command: nil,
                               urlTemplate: nil, fallbackURL: nil)
        try writer.append(newAction, expectedMTime: try writer.currentMTime())

        let actions = try read()
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[1].keyword, "todo")
    }

    func test_createsFile_whenMissing() throws {
        let writer = ConfigWriter(fileURL: configURL)
        let newAction = Action(keyword: "dl", title: "Downloads", type: .openFolder,
                               path: "~/Downloads", command: nil,
                               urlTemplate: nil, fallbackURL: nil)
        try writer.append(newAction, expectedMTime: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))
        let actions = try read()
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].keyword, "dl")
    }

    func test_appliedPermissions_are0600() throws {
        let writer = ConfigWriter(fileURL: configURL)
        let newAction = Action(keyword: "dl", title: "D", type: .openFolder,
                               path: "~/", command: nil,
                               urlTemplate: nil, fallbackURL: nil)
        try writer.append(newAction, expectedMTime: nil)

        let attrs = try FileManager.default.attributesOfItem(atPath: configURL.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        XCTAssertEqual(perms & 0o777, 0o600)
    }

    func test_mtimeConflict_rejectsWrite() throws {
        try """
        {"actions": []}
        """.data(using: .utf8)!.write(to: configURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)

        let writer = ConfigWriter(fileURL: configURL)
        let stale = Date(timeIntervalSince1970: 0)

        let newAction = Action(keyword: "x", title: "X", type: .openFolder,
                               path: "~/", command: nil,
                               urlTemplate: nil, fallbackURL: nil)

        XCTAssertThrowsError(try writer.append(newAction, expectedMTime: stale)) { error in
            XCTAssertEqual(error as? ConfigWriterError, .mtimeConflict)
        }

        // File contents must be unchanged (empty actions array, no 'x').
        let actions = try read()
        XCTAssertTrue(actions.isEmpty)
    }

    func test_appendToCorruptedFile_throws() throws {
        // Write a file that's valid JSON but not a valid Envelope
        try """
        {"version": "2.0", "items": []}
        """.data(using: .utf8)!.write(to: configURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)

        let writer = ConfigWriter(fileURL: configURL)
        let newAction = Action(keyword: "x", title: "X", type: .openFolder,
                               path: "~/", command: nil,
                               urlTemplate: nil, fallbackURL: nil)

        // Before the fix, this would silently succeed and destroy the file's content.
        // After the fix, it throws, leaving the original file intact.
        XCTAssertThrowsError(try writer.append(newAction, expectedMTime: try writer.currentMTime()))

        // The original file should be unchanged.
        let raw = try String(contentsOf: configURL)
        XCTAssertTrue(raw.contains("\"version\""))
        XCTAssertTrue(raw.contains("\"2.0\""))
    }

    func test_webSearch_roundtrip() throws {
        // Critical edge case: fallbackURL must survive a write+read cycle.
        let writer = ConfigWriter(fileURL: configURL)
        let webAction = Action(
            keyword: "g",
            title: "Google",
            type: .webSearch,
            path: nil,
            command: nil,
            urlTemplate: "https://google.com/?q={query}",
            fallbackURL: "https://google.com"
        )
        try writer.append(webAction, expectedMTime: nil)

        let actions = try read()
        XCTAssertEqual(actions.count, 1)
        let loaded = actions[0]
        XCTAssertEqual(loaded.keyword, "g")
        XCTAssertEqual(loaded.type, .webSearch)
        XCTAssertEqual(loaded.urlTemplate, "https://google.com/?q={query}")
        XCTAssertEqual(loaded.fallbackURL, "https://google.com",
                       "fallbackURL must survive ConfigWriter → ConfigLoader roundtrip")
    }
}
