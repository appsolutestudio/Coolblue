nonisolated struct ProductSearchPage: Equatable, Sendable {
    let products: [Product]
    let currentPage: Int
    let pageSize: Int
    let totalResults: Int
    let pageCount: Int
}

nonisolated extension ProductSearchPage {
    var nextPage: Int? {
        guard currentPage > 0, currentPage < pageCount else { return nil }
        return currentPage + 1
    }
}
