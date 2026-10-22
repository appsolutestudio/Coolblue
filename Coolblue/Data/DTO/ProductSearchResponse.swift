nonisolated struct ProductSearchResponse: Decodable, Sendable {
    let products: [ProductDTO]
    let currentPage: Int
    let pageSize: Int
    let totalResults: Int
    let pageCount: Int
}

nonisolated extension ProductSearchResponse {
    func toDomain() -> ProductSearchPage {
        ProductSearchPage(
            products: products.map { $0.toDomain() },
            currentPage: currentPage,
            pageSize: pageSize,
            totalResults: totalResults,
            pageCount: pageCount
        )
    }
}
