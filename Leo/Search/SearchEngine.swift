import Foundation

final class SearchEngine {
    private let actions: [Action]
    private let maxResults: Int

    init(actions: [Action], maxResults: Int = 8) {
        self.actions = actions
        self.maxResults = maxResults
    }

    func search(_ rawQuery: String) -> [SearchResult] {
        // Strip leading whitespace but preserve trailing space — the trailing space
        // is how the user signals "I'm about to type an argument".
        let leadingStripped = rawQuery.drop(while: { $0 == " " || $0 == "\t" })
        let trimmed = String(leadingStripped).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let spaceIndex = leadingStripped.firstIndex(of: " ") {
            let firstWord = String(leadingStripped[..<spaceIndex]).lowercased()
            let rest = String(leadingStripped[leadingStripped.index(after: spaceIndex)...])
            return argumentModeResults(firstWord: firstWord, rest: rest)
        }

        return plainResults(query: trimmed.lowercased())
    }

    // MARK: - Plain mode

    private func plainResults(query: String) -> [SearchResult] {
        let matches = actions.filter { $0.keyword.lowercased().hasPrefix(query) }
        let sorted = matches.sorted { lhs, rhs in
            let lExact = lhs.keyword.lowercased() == query
            let rExact = rhs.keyword.lowercased() == query
            if lExact != rExact { return lExact && !rExact }
            return lhs.keyword.localizedCaseInsensitiveCompare(rhs.keyword) == .orderedAscending
        }
        return sorted.prefix(maxResults).map { SearchResult(action: $0, argument: nil) }
    }

    // MARK: - Argument mode

    private func argumentModeResults(firstWord: String, rest: String) -> [SearchResult] {
        let matches = actions.filter {
            $0.keyword.lowercased() == firstWord && $0.acceptsArgument
        }
        return matches.prefix(maxResults).map { SearchResult(action: $0, argument: rest) }
    }
}
