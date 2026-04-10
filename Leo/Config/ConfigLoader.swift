import Foundation

struct ConfigLoadResult {
    let actions: [Action]
    let warnings: [String]
}

final class ConfigLoader {
    private let fileURL: URL
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Reads the config file and returns validated actions plus any warnings.
    /// Throws only for catastrophic failures (unreadable file, non-JSON root).
    /// Missing file → empty result, no warning.
    /// Malformed individual entries → dropped with a warning per entry.
    func load() throws -> ConfigLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ConfigLoadResult(actions: [], warnings: [])
        }

        var warnings: [String] = []

        // Permission check
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let perms = attrs[.posixPermissions] as? NSNumber {
            let mode = perms.uint16Value & 0o777
            if mode != 0o600 {
                warnings.append("Config file permissions are \(String(mode, radix: 8)) — expected 0600. " +
                                "Other local processes may be able to read or modify it.")
            }
        }

        let data = try Data(contentsOf: fileURL)
        let envelope = try decoder.decode(RawEnvelope.self, from: data)
        let rawActions = envelope.actions ?? []

        var validActions: [Action] = []
        for (index, rawAction) in rawActions.enumerated() {
            do {
                let action = try rawAction.toAction()
                try action.validate()
                validActions.append(action)
            } catch {
                let identifier = rawAction.keyword ?? "entry #\(index)"
                warnings.append("Dropped action '\(identifier)': \(error)")
            }
        }

        return ConfigLoadResult(actions: validActions, warnings: warnings)
    }
}

// Intermediate representation so that a single malformed entry doesn't sink the whole file.
private struct RawEnvelope: Decodable {
    let actions: [RawAction]?
}

private struct RawAction: Decodable {
    let keyword: String?
    let title: String?
    let type: String?
    let path: String?
    let command: String?
    let urlTemplate: String?
    let fallbackURL: String?

    private enum CodingKeys: String, CodingKey {
        case keyword
        case title
        case type
        case path
        case command
        case urlTemplate
        case fallbackURL = "fallbackUrl"
    }

    func toAction() throws -> Action {
        guard let keyword else { throw ConfigLoaderError.missingField("keyword") }
        guard let title else { throw ConfigLoaderError.missingField("title") }
        guard let typeString = type else { throw ConfigLoaderError.missingField("type") }
        guard let actionType = ActionType(rawValue: typeString) else {
            throw ConfigLoaderError.unknownType(typeString)
        }
        return Action(
            keyword: keyword,
            title: title,
            type: actionType,
            path: path,
            command: command,
            urlTemplate: urlTemplate,
            fallbackURL: fallbackURL
        )
    }
}

private enum ConfigLoaderError: Error, CustomStringConvertible {
    case missingField(String)
    case unknownType(String)

    var description: String {
        switch self {
        case .missingField(let name):
            return "missing required field '\(name)'"
        case .unknownType(let value):
            return "unknown action type '\(value)'"
        }
    }
}
