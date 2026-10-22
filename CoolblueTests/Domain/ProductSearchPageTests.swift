import Testing
@testable import Coolblue

struct ProductSearchPageTests {
    @Test(arguments: [(1, 2), (2, 3)])
    func advancesWhileMorePagesExist(currentPage: Int, expectedNextPage: Int) {
        let result = page(current: currentPage, count: 3)

        #expect(result.nextPage == expectedNextPage)
    }

    @Test func stopsAtLastPage() {
        #expect(page(current: 3, count: 3).nextPage == nil)
    }

    @Test func stopsBeyondLastPage() {
        #expect(page(current: 4, count: 3).nextPage == nil)
    }

    @Test func stopsForEmptySearch() {
        #expect(page(current: 1, count: 0).nextPage == nil)
    }

    @Test(arguments: [0, -1])
    func doesNotAdvanceInvalidPage(currentPage: Int) {
        #expect(page(current: currentPage, count: 3).nextPage == nil)
    }
}

private extension ProductSearchPageTests {
    func page(current: Int, count: Int) -> ProductSearchPage {
        ProductSearchPage(
            products: [],
            currentPage: current,
            pageSize: 24,
            totalResults: count == 0 ? 0 : 70,
            pageCount: count
        )
    }
}
