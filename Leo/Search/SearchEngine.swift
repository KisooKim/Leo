import Foundation

final class SearchEngine {
    private let actions: [Action]
    private let maxResults: Int

    init(actions: [Action], maxResults: Int = 8) {
        self.actions = actions
        self.maxResults = maxResults
    }

    func search(_ rawQuery: String) -> [SearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        // Keep the raw (un-trimmed) query around so a trailing space still triggers
        // argument mode with an empty argument. But we only care about the first
        // space in the *raw* input.
        if let spaceIndex = rawQuery.firstIndex(of: " ") {
            let firstWord = String(rawQuery[..<spaceIndex]).lowercased()
            let rest = String(rawQuery[rawQuery.index(after: spaceIndex)...])
            return argumentModeResults(firstWord: firstWord, rest: rest)
        }

        return plainResults(query: query.lowercased())
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
