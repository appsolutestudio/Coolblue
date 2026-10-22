import Foundation

nonisolated struct ProductSearchResponse: Decodable, Sendable {
    let products: [ProductDTO]
    let currentPage: Int
    let pageSize: Int
    let totalResults: Int
    let pageCount: Int
}

nonisolated struct ProductDTO: Decodable, Sendable {
    let productId: Int
    let productName: String
    let salesPriceIncVat: Decimal
    let productImage: String?
    let usps: [String]?
    let reviewInformation: ReviewInformation
    let nextDayDelivery: Bool?

    private enum CodingKeys: String, CodingKey {
        case productId, productName, salesPriceIncVat, productImage
        case usps = "USPs"
        case reviewInformation, nextDayDelivery
    }

    struct ReviewInformation: Decodable, Sendable {
        let reviewSummary: ReviewSummary
    }

    struct ReviewSummary: Decodable, Sendable {
        let reviewAverage: Double
        let reviewCount: Int
    }
}

nonisolated extension ProductDTO {
    func toDomain() -> Product {
        let summary = reviewInformation.reviewSummary

        return Product(
            id: productId,
            name: productName,
            price: salesPriceIncVat,
            imageURL: imageURL,
            highlights: usps ?? [],
            review: Product.Review(average: summary.reviewAverage, count: summary.reviewCount),
            nextDayDelivery: nextDayDelivery
        )
    }

    private var imageURL: URL? {
        guard let productImage,
              let url = URL(string: productImage),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            return nil
        }

        return url
    }
}
