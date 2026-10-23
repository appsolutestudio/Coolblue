#if DEBUG
import Foundation

// Selected only by the app's composition root when a UI test scenario is supplied.
actor UITestProductSearchRepository: ProductSearchRepository {
    nonisolated enum Scenario: String, Sendable {
        case results
        case empty
        case searchRetry
        case paginationRetry
        case rating1
        case rating3
        case rating5
    }

    private let scenario: Scenario
    private var queriesWithFailure: Set<String> = []

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func search(query: String, page: Int) async throws -> ProductSearchPage {
        try Task.checkCancellation()

        if scenario == .empty {
            return ProductSearchPage(
                products: [], currentPage: page, pageSize: 12, totalResults: 0, pageCount: 0
            )
        }

        let reviewAverage: Double = switch scenario {
        case .rating1: 1
        case .rating3: 3
        case .rating5: 5
        default: 9.2
        }

        let failingPage: Int? = switch scenario {
        case .searchRetry: 1
        case .paginationRetry: 2
        default: nil
        }
        if page == failingPage, queriesWithFailure.insert(query).inserted {
            throw Failure.unavailable
        }

        guard (1...2).contains(page) else { throw Failure.unavailable }
        let ids = page == 1 ? 1...12 : 13...14
        return ProductSearchPage(
            products: ids.map { id in
                Product(
                    id: id,
                    name: "Test phone \(id)",
                    price: 499,
                    imageURL: nil,
                    highlights: ["256 GB storage", "OLED display"],
                    review: Product.Review(average: reviewAverage, count: 42),
                    nextDayDelivery: true
                )
            },
            currentPage: page,
            pageSize: 12,
            totalResults: 14,
            pageCount: 2
        )
    }

    private enum Failure: Error {
        case unavailable
    }
}
#endif
