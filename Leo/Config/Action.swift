import Foundation

enum ActionType: String, Codable, CaseIterable {
    case openFolder = "open_folder"
    case openFile   = "open_file"
    case runBash    = "run_bash"
    case webSearch  = "web_search"
}

struct Action: Codable, Equatable, Hashable {
    let keyword: String
    let title: String
    let type: ActionType
    let path: String?
    let command: String?
    let urlTemplate: String?
    let fallbackURL: String?

    enum CodingKeys: String, CodingKey {
        case keyword
        case title
        case type
        case path
        case command
        case urlTemplate
        case fallbackURL    = "fallbackUrl"
    }
}

extension Action {
    /// Whether this action consumes an argument typed after the keyword
    /// (e.g., `amazon desk` → argument `desk`).
    var acceptsArgument: Bool { type == .webSearch }

    func validate() throws {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { throw ActionValidationError.emptyKeyword }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw ActionValidationError.emptyTitle }

        switch type {
        case .openFolder, .openFile:
            // Trim path to reject whitespace-only configs; the tilde-expansion and
            // file access at execution time will accept trimmed paths as-is.
            guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                throw ActionValidationError.missingPath
            }
        case .runBash:
            guard let trimmed = command?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                throw ActionValidationError.missingCommand
            }
        case .webSearch:
            guard let trimmed = urlTemplate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                throw ActionValidationError.missingURLTemplate
            }
            guard trimmed.contains("{query}") else {
                throw ActionValidationError.missingQueryPlaceholder
            }
        }
    }
}

enum ActionValidationError: Error, Equatable {
    case emptyKeyword
    case emptyTitle
    case missingPath
    case missingCommand
    case missingURLTemplate
    case missingQueryPlaceholder
}
