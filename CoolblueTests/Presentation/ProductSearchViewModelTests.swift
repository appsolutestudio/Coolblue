import Foundation
import Testing
@testable import Coolblue

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductSearchViewModelTests {
    @Test func startsIdleAndIgnoresUnavailableActions() async {
        let repository = ControlledProductSearchRepository()
        let model = ProductSearchViewModel(repository: repository)

        #expect(model.state == .idle)
        #expect(model.products.isEmpty)
        #expect(model.query.isEmpty)
        #expect(model.paginationState == .idle)
        #expect(!model.canLoadMore)
        #expect(model.retrySearch() == nil)
        #expect(model.loadNextPage() == nil)
        #expect(model.retryNextPage() == nil)
        #expect(await repository.requests.isEmpty)
    }

    @Test func trimsSubmittedQueryAndIgnoresDuplicateInFlightSubmission() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)

        let task = try #require(model.search(query: " \n apple \t "))
        #expect(model.state == .loading)
        #expect(model.query == "apple")
        let request = try #require(await requests.next())
        #expect(request.query == "apple")
        #expect(request.page == 1)
        #expect(model.search(query: "apple") == nil)

        await repository.complete(request, with: .success(page([product(1)], current: 1, count: 2)))
        await task.value

        #expect(model.state == .results([product(1)]))
        #expect(model.nextPage == 2)
        #expect(model.canLoadMore)
        #expect(await repository.requests.count == 1)
    }

    @Test(arguments: ["", " \n\t "])
    func ignoresBlankQuery(query: String) async {
        let repository = ControlledProductSearchRepository()
        let model = ProductSearchViewModel(repository: repository)

        #expect(model.search(query: query) == nil)
        #expect(model.state == .idle)
        #expect(model.query.isEmpty)
        #expect(await repository.requests.isEmpty)
    }

    @Test func blankSubmissionClearsSearchAndInvalidatesPendingResponse() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let task = try #require(model.search(query: "apple"))
        let request = try #require(await requests.next())

        #expect(model.search(query: " \n ") == nil)
        #expect(task.isCancelled)
        #expect(model.state == .idle)
        #expect(model.query.isEmpty)

        await repository.complete(request, with: .success(page([product(1)], current: 1, count: 3)))
        await task.value

        #expect(model.state == .idle)
        #expect(model.nextPage == nil)
    }

    @Test func emptyResponseStopsPagination() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let task = try #require(model.search(query: "missing"))
        let request = try #require(await requests.next())

        await repository.complete(request, with: .success(page([], current: 1, count: 3)))
        await task.value

        #expect(model.state == .empty)
        #expect(model.nextPage == nil)
        #expect(!model.canLoadMore)
    }

    @Test func retriesFailedInitialSearch() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let task = try #require(model.search(query: "apple"))
        let request = try #require(await requests.next())

        await repository.complete(request, with: .failure(SearchFailure.unavailable))
        await task.value

        #expect(model.state == .failed)
        #expect(model.products.isEmpty)
        #expect(!model.canLoadMore)

        let retry = try #require(model.retrySearch())
        let retriedRequest = try #require(await requests.next())
        #expect(model.state == .loading)
        #expect(retriedRequest.query == "apple")
        #expect(retriedRequest.page == 1)
        await repository.complete(retriedRequest, with: .success(page([product(1)])))
        await retry.value

        #expect(model.state == .results([product(1)]))
    }

    @Test func deduplicatesWithinAndAcrossPagesPreservingFirstOccurrenceAndOrder() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let first = product(2, name: "First occurrence")
        let duplicate = product(2, name: "Later occurrence")
        let search = try #require(model.search(query: "apple"))
        let firstRequest = try #require(await requests.next())
        await repository.complete(firstRequest, with: .success(page([first, product(1), duplicate], count: 2)))
        await search.value

        #expect(model.products == [first, product(1)])
        let loadMore = try #require(model.loadNextPage())
        let nextRequest = try #require(await requests.next())
        #expect(nextRequest.query == "apple")
        #expect(nextRequest.page == 2)
        #expect(model.products == [first, product(1)])
        #expect(model.paginationState == .loading)
        #expect(model.loadNextPage() == nil)
        #expect(!model.canLoadMore)

        await repository.complete(
            nextRequest, with: .success(page([duplicate, product(3), product(3), product(4)], current: 2, count: 2))
        )
        await loadMore.value

        #expect(model.products == [first, product(1), product(3), product(4)])
        #expect(model.paginationState == .idle)
        #expect(model.nextPage == nil)
        #expect(model.loadNextPage() == nil)
        #expect(await repository.requests.count == 2)
    }

    @Test(arguments: [[], [1, 1]])
    func stopsWhenLaterPageAddsNoNewProducts(ids: [Int]) async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let search = try #require(model.search(query: "apple"))
        let firstRequest = try #require(await requests.next())
        await repository.complete(firstRequest, with: .success(page([product(1)], count: 3)))
        await search.value
        let loadMore = try #require(model.loadNextPage())
        let nextRequest = try #require(await requests.next())

        await repository.complete(nextRequest, with: .success(page(ids.map { product($0) }, current: 2, count: 3)))
        await loadMore.value

        #expect(model.state == .results([product(1)]))
        #expect(model.paginationState == .idle)
        #expect(model.nextPage == nil)
        #expect(!model.canLoadMore)
    }

    @Test func failedPageRetainsProductsAndRequiresExplicitRetryForSamePage() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let search = try #require(model.search(query: "apple"))
        let firstRequest = try #require(await requests.next())
        await repository.complete(firstRequest, with: .success(page([product(1)], count: 3)))
        await search.value
        let loadMore = try #require(model.loadNextPage())
        let nextRequest = try #require(await requests.next())
        await repository.complete(nextRequest, with: .failure(SearchFailure.unavailable))
        await loadMore.value

        #expect(model.state == .results([product(1)]))
        #expect(model.paginationState == .failed)
        #expect(model.nextPage == 2)
        #expect(!model.canLoadMore)
        #expect(model.loadNextPage() == nil)
        model.cancel()
        #expect(model.paginationState == .failed)
        #expect(model.loadNextPage() == nil)

        let retry = try #require(model.retryNextPage())
        let retriedRequest = try #require(await requests.next())
        #expect(retriedRequest.query == "apple")
        #expect(retriedRequest.page == 2)
        #expect(model.paginationState == .loading)
        #expect(model.retryNextPage() == nil)
        await repository.complete(retriedRequest, with: .success(page([product(2)], current: 2, count: 3)))
        await retry.value

        #expect(model.products == [product(1), product(2)])
        #expect(model.nextPage == 3)
        #expect(model.canLoadMore)
    }

    @Test(arguments: [false, true], [false, true])
    func ignoresSupersededSuccessAndFailure(fromPagination: Bool, fails: Bool) async throws {
        // This fake deliberately ignores cancellation, so late completions reach the view model.
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        var oldTask = try #require(model.search(query: "old"))
        var oldRequest = try #require(await requests.next())
        if fromPagination {
            await repository.complete(oldRequest, with: .success(page([product(1)], count: 3)))
            await oldTask.value
            oldTask = try #require(model.loadNextPage())
            oldRequest = try #require(await requests.next())
        }

        let currentTask = try #require(model.search(query: "current"))
        let currentRequest = try #require(await requests.next())
        #expect(oldTask.isCancelled)
        #expect(model.products.isEmpty)
        #expect(model.paginationState == .idle)
        await repository.complete(currentRequest, with: .success(page([product(9)])))
        await currentTask.value

        let oldResult: Result<ProductSearchPage, any Error> = fails
            ? .failure(SearchFailure.unavailable)
            : .success(page([product(2)], current: oldRequest.page, count: 3))
        await repository.complete(oldRequest, with: oldResult)
        await oldTask.value

        #expect(model.query == "current")
        #expect(model.state == .results([product(9)]))
        #expect(model.paginationState == .idle)
        #expect(model.nextPage == nil)
    }

    @Test func generationRejectsOlderResponseForSameQuery() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let first = try #require(model.search(query: "apple"))
        let firstRequest = try #require(await requests.next())
        let second = try #require(model.search(query: "banana"))
        let secondRequest = try #require(await requests.next())
        let third = try #require(model.search(query: "apple"))
        let thirdRequest = try #require(await requests.next())

        await repository.complete(firstRequest, with: .success(page([product(1)])))
        await first.value
        await repository.complete(secondRequest, with: .failure(SearchFailure.unavailable))
        await second.value
        #expect(model.query == "apple")
        #expect(model.state == .loading)

        await repository.complete(thirdRequest, with: .success(page([product(3)])))
        await third.value
        #expect(model.state == .results([product(3)]))
    }

    @Test(arguments: [false, true], [false, true])
    func cancellationClearsLoadingWithoutAnError(fromPagination: Bool, cancelsExplicitly: Bool) async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        var task = try #require(model.search(query: "apple"))
        var request = try #require(await requests.next())
        if fromPagination {
            await repository.complete(request, with: .success(page([product(1)], count: 2)))
            await task.value
            task = try #require(model.loadNextPage())
            request = try #require(await requests.next())
        }

        if cancelsExplicitly {
            model.cancel()
            #expect(task.isCancelled)
            #expect(model.state == (fromPagination ? .results([product(1)]) : .idle))
            #expect(model.paginationState == .idle)
        }
        await repository.complete(request, with: .failure(CancellationError()))
        await task.value

        #expect(model.state == (fromPagination ? .results([product(1)]) : .idle))
        #expect(model.paginationState == .idle)
        #expect(model.canLoadMore == fromPagination)
    }

    @Test func explicitCancellationInvalidatesLateFailureAndAllowsResubmission() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let task = try #require(model.search(query: "apple"))
        let request = try #require(await requests.next())

        model.cancel()
        #expect(task.isCancelled)
        #expect(model.state == .idle)
        await repository.complete(request, with: .failure(SearchFailure.unavailable))
        await task.value
        #expect(model.state == .idle)

        let resubmission = try #require(model.search(query: "apple"))
        let resubmittedRequest = try #require(await requests.next())
        await repository.complete(resubmittedRequest, with: .success(page([product(1)])))
        await resubmission.value
        #expect(model.state == .results([product(1)]))
    }

    @Test(arguments: [false, true])
    func directlyCancelledTaskIgnoresLateCompletion(fails: Bool) async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        let model = ProductSearchViewModel(repository: repository)
        let task = try #require(model.search(query: "apple"))
        let request = try #require(await requests.next())

        // Cancelling the returned task does not invalidate the model's generation.
        task.cancel()
        let result: Result<ProductSearchPage, any Error> = fails
            ? .failure(SearchFailure.unavailable)
            : .success(page([product(1)]))
        await repository.complete(request, with: result)
        await task.value

        #expect(model.state == .idle)
        #expect(model.paginationState == .idle)
        #expect(model.nextPage == nil)
    }

    @Test func cancellationBeforeTaskStartsAvoidsRequest() async throws {
        let repository = ControlledProductSearchRepository()
        let model = ProductSearchViewModel(repository: repository)
        let task = try #require(model.search(query: "apple"))

        task.cancel()
        await task.value

        #expect(model.state == .idle)
        #expect(await repository.requests.isEmpty)
    }

    @Test func releasingViewModelCancelsRequestWithoutRetainingModel() async throws {
        let repository = ControlledProductSearchRepository()
        var requests = repository.startedRequests.makeAsyncIterator()
        var model: ProductSearchViewModel? = ProductSearchViewModel(repository: repository)
        weak let weakModel = model
        let task = try #require(model?.search(query: "apple"))
        let request = try #require(await requests.next())

        model = nil

        #expect(weakModel == nil)
        #expect(task.isCancelled)
        await repository.complete(request, with: .success(page([product(1)])))
        await task.value
    }
}

private extension ProductSearchViewModelTests {
    func product(_ id: Int, name: String = "Product") -> Product {
        Product(
            id: id, name: name, price: 10, imageURL: nil, highlights: [],
            review: Product.Review(average: 9, count: 1), nextDayDelivery: nil
        )
    }

    func page(_ products: [Product], current: Int = 1, count: Int = 1) -> ProductSearchPage {
        ProductSearchPage(products: products, currentPage: current, pageSize: 24, totalResults: 70, pageCount: count)
    }
}

private enum SearchFailure: Error {
    case unavailable
}

private actor ControlledProductSearchRepository: ProductSearchRepository {
    struct Request: Sendable {
        let id: Int
        let query: String
        let page: Int
    }

    nonisolated let startedRequests: AsyncStream<Request>
    private let started: AsyncStream<Request>.Continuation
    private(set) var requests: [Request] = []
    private var pending: [Int: CheckedContinuation<ProductSearchPage, any Error>] = [:]

    init() {
        (startedRequests, started) = AsyncStream.makeStream()
    }

    func search(query: String, page: Int) async throws -> ProductSearchPage {
        try await withCheckedThrowingContinuation { continuation in
            let request = Request(id: requests.count, query: query, page: page)
            requests.append(request)
            pending[request.id] = continuation
            started.yield(request)
        }
    }

    func complete(_ request: Request, with result: Result<ProductSearchPage, any Error>) {
        pending.removeValue(forKey: request.id)?.resume(with: result)
    }
}
