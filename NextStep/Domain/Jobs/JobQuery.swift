import Foundation

/// Query conditions for the remote job source. Manual and URL sources receive their input at init.
nonisolated struct JobQuery: Sendable, Equatable {
    var keyword: String?
    var category: String?
    var limit: Int

    init(keyword: String? = nil, category: String? = "software-dev", limit: Int = 50) {
        self.keyword = keyword
        self.category = category
        self.limit = limit
    }
}
