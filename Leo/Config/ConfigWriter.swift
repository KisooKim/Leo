import Foundation

enum ConfigWriterError: Error, Equatable {
    case mtimeConflict
}

final class ConfigWriter {
    private let fileURL: URL
    private let fileManager = FileManager.default
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL) {
        self.fileURL = fileURL

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    /// Returns the current on-disk mtime, or nil if the file doesn't exist yet.
    /// Callers should capture this at load time and pass it back to `append` so
    /// a concurrent hand-edit is not clobbered.
    func currentMTime() throws -> Date? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
        return attrs[.modificationDate] as? Date
    }

    /// Appends `action` to the config file. If `expectedMTime` doesn't match the
    /// on-disk mtime, throws `.mtimeConflict` and leaves the file untouched.
    /// Writes atomically via a sibling temp file, then `chmod 0600`.
    func append(_ action: Action, expectedMTime: Date?) throws {
        // 1. Conflict check
        if fileManager.fileExists(atPath: fileURL.path) {
            let currentMTime = try currentMTime()
            if expectedMTime != currentMTime {
                throw ConfigWriterError.mtimeConflict
            }
        } else {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        // 2. Load current actions (or start empty)
        var existing: [Action] = []
        if fileManager.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let envelope = try decoder.decode(Envelope.self, from: data)
            existing = envelope.actions
        }
        existing.append(action)

        // 3. Encode
        let newEnvelope = Envelope(actions: existing)
        let data = try encoder.encode(newEnvelope)

        // 4. Write to sibling temp, fsync, rename
        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).tmp.\(UUID().uuidString)")

        try data.write(to: tempURL, options: .atomic)
        do {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }

        // 5. Apply 0600 permissions
        try fileManager.setAttributes([.posixPermissions: 0o600],
                                      ofItemAtPath: fileURL.path)
    }

    private struct Envelope: Codable {
        let actions: [Action]
    }
}
