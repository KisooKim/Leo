import Foundation

struct SearchResult: Equatable {
    let action: Action
    /// Non-nil iff this result was produced in argument mode.
    let argument: String?

    /// The label to display in the result row. In plain mode this is
    /// `action.title`; in argument mode it overlays the argument.
    var displayTitle: String {
        if let argument {
            return "Search \(action.title) for '\(argument)'"
        }
        return action.title
    }
}
