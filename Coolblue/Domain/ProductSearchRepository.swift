nonisolated protocol ProductSearchRepository: Sendable {
    func search(query: String, page: Int) async throws -> ProductSearchPage
}
