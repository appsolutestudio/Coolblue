import Foundation
import Observation

@MainActor
@Observable
final class ProductSearchViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results([Product])
        case empty
        case failed
    }

    enum PaginationState: Equatable {
        case idle
        case loading
        case failed
    }

    private(set) var state: State = .idle
    private(set) var paginationState: PaginationState = .idle
    private(set) var query = ""
    private(set) var nextPage: Int?

    var products: [Product] {
        guard case .results(let products) = state else { return [] }
        return products
    }

    var canLoadMore: Bool {
        nextPage != nil && paginationState == .idle
    }

    private let repository: any ProductSearchRepository
    @ObservationIgnored private var requestTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(repository: any ProductSearchRepository) {
        self.repository = repository
    }

    deinit {
        requestTask?.cancel()
    }
}

extension ProductSearchViewModel {
    @discardableResult
    func search(query input: String) -> Task<Void, Never>? {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != self.query || requestTask == nil else { return nil }

        invalidateRequest()
        self.query = query
        nextPage = nil
        paginationState = .idle

        guard !query.isEmpty else {
            state = .idle
            return nil
        }

        state = .loading
        return startRequest(page: 1)
    }

    @discardableResult
    func retrySearch() -> Task<Void, Never>? {
        guard state == .failed else { return nil }
        return search(query: query)
    }

    @discardableResult
    func loadNextPage() -> Task<Void, Never>? {
        guard canLoadMore, let nextPage else { return nil }
        paginationState = .loading
        return startRequest(page: nextPage)
    }

    @discardableResult
    func retryNextPage() -> Task<Void, Never>? {
        guard paginationState == .failed, let nextPage else { return nil }
        paginationState = .loading
        return startRequest(page: nextPage)
    }

    func cancel() {
        invalidateRequest()
        restoreAfterCancellation()
    }
}

private extension ProductSearchViewModel {
    func invalidateRequest() {
        // Invalidate before cancellation, since a repository may still return a result.
        generation += 1
        requestTask?.cancel()
        requestTask = nil
    }

    func startRequest(page: Int) -> Task<Void, Never> {
        let generation = self.generation
        let query = self.query
        let repository = self.repository

        let task = Task<Void, Never> { [weak self] in
            let result: Result<ProductSearchPage, any Error>
            do {
                try Task.checkCancellation()
                result = .success(try await repository.search(query: query, page: page))
            } catch {
                result = .failure(error)
            }

            self?.handleSearchCompletion(result, page: page, generation: generation)
        }
        requestTask = task
        return task
    }

    func handleSearchCompletion(
        _ result: Result<ProductSearchPage, any Error>,
        page: Int,
        generation: Int
    ) {
        guard generation == self.generation else { return }
        requestTask = nil

        guard !Task.isCancelled else {
            restoreAfterCancellation()
            return
        }

        switch result {
        case .success(let loadedPage):
            applySearchPage(loadedPage)
        case .failure(let error) where error is CancellationError:
            restoreAfterCancellation()
        case .failure:
            if page == 1 {
                state = .failed
            } else {
                paginationState = .failed
            }
        }
    }

    func applySearchPage(_ loadedPage: ProductSearchPage) {
        var knownIDs = Set(products.map(\.id))
        let newProducts = loadedPage.products.filter { knownIDs.insert($0.id).inserted }
        let mergedProducts = products + newProducts

        state = mergedProducts.isEmpty ? .empty : .results(mergedProducts)
        nextPage = newProducts.isEmpty ? nil : loadedPage.nextPage
        paginationState = .idle
    }

    func restoreAfterCancellation() {
        if state == .loading {
            state = .idle
        }
        if paginationState == .loading {
            paginationState = .idle
        }
    }
}
