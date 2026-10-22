import Foundation
import Testing
@testable import Coolblue

struct ProductSearchResponseTests {
    @Test func decodesSuppliedFixture() throws {
        let response = try JSONDecoder().decode(
            ProductSearchResponse.self, from: Fixtures.data(named: "product-search")
        )
        let products = response.products.map { $0.toDomain() }

        #expect(products.count == 22)
        #expect(Set(products.map(\.id)).count == products.count)
        #expect(products.allSatisfy { $0.imageURL != nil })
        #expect(response.currentPage == 3)
        #expect(response.pageSize == 24)
        #expect(response.totalResults == 70)
        #expect(response.pageCount == 3)

        let adapter = try #require(products.first { $0.id == 232406 })
        let phone = try #require(products.first { $0.id == 793684 })
        #expect(adapter.price == Decimal(string: "24.99"))
        #expect(phone.price == Decimal(string: "1042.99"))
    }

    @Test func mapsProductToDomain() throws {
        // Reduced from the supplied API response, including fields we do not consume.
        let product = try decodeProduct("""
        {
            "productId": 793652,
            "productName": "Apple iPhone X 256GB Zilver",
            "salesPriceIncVat": 1279,
            "productImage": "https://image.coolblue.nl/300x750/products/984921",
            "USPs": ["256 GB opslagcapaciteit", "iOS 11"],
            "reviewInformation": {
                "reviews": [],
                "reviewSummary": {"reviewAverage": 9.2, "reviewCount": 209}
            },
            "availabilityState": 2,
            "nextDayDelivery": true
        }
        """).toDomain()

        #expect(product == Product(
            id: 793652,
            name: "Apple iPhone X 256GB Zilver",
            price: Decimal(1279),
            imageURL: URL(string: "https://image.coolblue.nl/300x750/products/984921"),
            highlights: ["256 GB opslagcapaciteit", "iOS 11"],
            review: Product.Review(average: 9.2, count: 209),
            nextDayDelivery: true
        ))
    }

    @Test func mapsReviewOutsideMainActor() async throws {
        let product = try await Task.detached {
            let json = """
            {
                "productId": 1, "productName": "Product", "salesPriceIncVat": 10,
                "reviewInformation": {
                    "reviewSummary": {"reviewAverage": 9.2, "reviewCount": 209}
                }
            }
            """
            return try JSONDecoder().decode(ProductDTO.self, from: Data(json.utf8)).toDomain()
        }.value

        #expect(product.review == Product.Review(average: 9.2, count: 209))
    }

    @Test(arguments: ["24.99", "1042.99", "0.1", "0.01", "1279", "99999.99"])
    func preservesDecimalPrice(value: String) throws {
        let product = try decodeProduct("""
        {"productId": 1, "productName": "Product", "salesPriceIncVat": \(value), "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}
        """).toDomain()
        let expected = try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
        #expect(product.price == expected)
    }

    @Test func mapsMissingOptionalDetails() throws {
        let product = try decodeProduct("""
        {"productId": 1, "productName": "Product", "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}
        """).toDomain()
        #expect(product.imageURL == nil)
        #expect(product.highlights.isEmpty)
        #expect(product.review == Product.Review(average: 0, count: 0))
        #expect(product.nextDayDelivery == nil)
    }

    @Test func mapsNullOptionalDetails() throws {
        let product = try decodeProduct("""
        {
            "productId": 1, "productName": "Product", "salesPriceIncVat": 10,
            "productImage": null, "USPs": null,
            "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}, "nextDayDelivery": null
        }
        """).toDomain()
        #expect(product.imageURL == nil)
        #expect(product.highlights.isEmpty)
        #expect(product.review == Product.Review(average: 0, count: 0))
        #expect(product.nextDayDelivery == nil)
    }

    @Test(arguments: [true, false])
    func preservesExplicitDeliveryAvailability(value: Bool) throws {
        let product = try decodeProduct("""
        {"productId": 1, "productName": "Product", "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}, "nextDayDelivery": \(value)}
        """).toDomain()
        #expect(product.nextDayDelivery == value)
    }

    @Test func rejectsMissingReviewSummary() {
        #expect {
            try decodeProduct("""
            {
                "productId": 1, "productName": "Product", "salesPriceIncVat": 10,
                "reviewInformation": {"reviews": []}
            }
            """)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == "reviewSummary"
                && context.codingPath.map(\.stringValue) == ["reviewInformation"]
        }
    }

    @Test func rejectsNullReviewSummary() {
        #expect {
            try decodeProduct("""
            {
                "productId": 1, "productName": "Product", "salesPriceIncVat": 10,
                "reviewInformation": {"reviewSummary": null}
            }
            """)
        } throws: { error in
            guard case DecodingError.valueNotFound(_, let context) = error else { return false }
            return context.codingPath.map(\.stringValue) == ["reviewInformation", "reviewSummary"]
        }
    }

    @Test(arguments: [
        (#"{"reviewAverage": 9.2}"#, "reviewCount"),
        (#"{"reviewCount": 209}"#, "reviewAverage")
    ])
    func rejectsIncompleteReviewSummary(summary: String, missingKey: String) {
        let json = """
        {
            "productId": 1, "productName": "Product", "salesPriceIncVat": 10,
            "reviewInformation": {"reviewSummary": \(summary)}
        }
        """
        #expect {
            try decodeProduct(json)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == missingKey
                && context.codingPath.map(\.stringValue) == ["reviewInformation", "reviewSummary"]
        }
    }

    @Test(arguments: [
        (#""nextDayDelivery": "yes""#, "nextDayDelivery"),
        (#""USPs": "text""#, "USPs")
    ])
    func rejectsWrongTypedOptionalFields(fragment: String, field: String) {
        let json = """
        {"productId": 1, "productName": "Product", "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}, \(fragment)}
        """
        #expect {
            try decodeProduct(json)
        } throws: { error in
            guard case DecodingError.typeMismatch(_, let context) = error else { return false }
            return context.codingPath.map(\.stringValue) == [field]
        }
    }

    @Test(arguments: ["", "not a URL", "/products/123", "file:///tmp/image.png", "https://"])
    func ignoresInvalidImageURL(value: String) throws {
        let product = try decodeProduct("""
        {"productId": 1, "productName": "Product", "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}, "productImage": "\(value)"}
        """).toDomain()
        #expect(product.imageURL == nil)
    }

    @Test func decodesEmptyResults() throws {
        let response = try JSONDecoder().decode(ProductSearchResponse.self, from: Fixtures.emptyPage)
        #expect(response.products.isEmpty)
    }

    @Test func rejectsMissingProducts() {
        #expect {
            try decode(#"{"currentPage": 1, "pageSize": 24, "totalResults": 0, "pageCount": 0}"#)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == "products" && context.codingPath.isEmpty
        }
    }

    @Test func rejectsNullProducts() {
        #expect {
            try decode(#"{"products": null, "currentPage": 1, "pageSize": 24, "totalResults": 0, "pageCount": 0}"#)
        } throws: { error in
            guard case DecodingError.valueNotFound(_, let context) = error else { return false }
            return context.codingPath.map(\.stringValue) == ["products"]
        }
    }

    @Test func rejectsWrongTypedPageNumber() {
        #expect {
            try decode(#"{"products": [], "currentPage": "one", "pageSize": 24, "totalResults": 0, "pageCount": 0}"#)
        } throws: { error in
            guard case DecodingError.typeMismatch(_, let context) = error else { return false }
            return context.codingPath.map(\.stringValue) == ["currentPage"]
        }
    }

    @Test(arguments: [
        (#"{"productName": "Product", "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}"#, "productId"),
        (#"{"productId": 1, "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}"#, "productName"),
        (#"{"productId": 1, "productName": "Product", "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}"#, "salesPriceIncVat")
    ])
    func rejectsMissingRequiredProductFields(json: String, missingKey: String) {
        #expect {
            try decodeProduct(json)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == missingKey && context.codingPath.isEmpty
        }
    }

    @Test func rejectsMissingReviewInformation() {
        #expect {
            try decodeProduct(#"{"productId": 1, "productName": "Product", "salesPriceIncVat": 10}"#)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == "reviewInformation" && context.codingPath.isEmpty
        }
    }

    @Test func rejectsNullReviewInformation() {
        #expect {
            try decodeProduct("""
            {"productId": 1, "productName": "Product", "salesPriceIncVat": 10, "reviewInformation": null}
            """)
        } throws: { error in
            guard case DecodingError.valueNotFound(_, let context) = error else { return false }
            return context.codingPath.map(\.stringValue) == ["reviewInformation"]
        }
    }

    @Test func rejectsInvalidPrice() {
        #expect {
            try decodeProduct(#"{"productId": 1, "productName": "Product", "salesPriceIncVat": "invalid", "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}"#)
        } throws: { error in
            switch error {
            case DecodingError.typeMismatch(_, let context), DecodingError.dataCorrupted(let context):
                return context.codingPath.map(\.stringValue) == ["salesPriceIncVat"]
            default:
                return false
            }
        }
    }

    @Test func rejectsResponseContainingInvalidProduct() {
        let json = """
        {
            "products": [
                {"productId": 1, "productName": "Valid", "salesPriceIncVat": 10, "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}},
                {"productId": 2, "productName": "Missing price", "reviewInformation": {"reviewSummary": {"reviewAverage": 0, "reviewCount": 0}}}
            ],
            "currentPage": 1, "pageSize": 24, "totalResults": 2, "pageCount": 1
        }
        """
        #expect {
            try decode(json)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == "salesPriceIncVat"
                && context.codingPath.count == 2
                && context.codingPath[0].stringValue == "products"
                && context.codingPath[1].intValue == 1
        }
    }
}

private extension ProductSearchResponseTests {
    func decode(_ json: String) throws -> ProductSearchResponse {
        try JSONDecoder().decode(ProductSearchResponse.self, from: Data(json.utf8))
    }

    func decodeProduct(_ json: String) throws -> ProductDTO {
        try JSONDecoder().decode(ProductDTO.self, from: Data(json.utf8))
    }
}
