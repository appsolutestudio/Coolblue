import Foundation
import Testing
@testable import Coolblue

@Suite(.timeLimit(.minutes(1)))
struct APIProductSearchRepositoryTests {
    private let baseURL: URL

    init() throws {
        baseURL = try #require(URL(string: "https://example.invalid/mobile-assignment"))
    }

    @Test(arguments: [200, 201, 299])
    func mapsSuccessfulResponse(status: Int) async throws {
        let stub = StubbedSession(response: .http(status: status, data: try Fixtures.data(named: "product-search")))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        let result = try await repository.search(query: "apple", page: 3)

        #expect(result.products.count == 22)
        #expect(result.currentPage == 3)
        #expect(result.pageSize == 24)
        #expect(result.totalResults == 70)
        #expect(result.pageCount == 3)
        #expect(result.nextPage == nil)
        let product = try #require(result.products.first { $0.id == 232406 })
        #expect(product.price == Decimal(string: "24.99"))
        #expect(product.review == Product.Review(average: 9, count: 36))
    }

    @Test func buildsSearchRequest() async throws {
        let stub = StubbedSession(response: .http(status: 200, data: try Fixtures.data(named: "product-search")))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)
        let query = "C++ & café / โทรศัพท์? #1 = 50%"

        _ = try await repository.search(query: query, page: 3)

        let request = try #require(stub.requests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(stub.requests.count == 1)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.timeoutInterval == 30)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(components.scheme == "https")
        #expect(components.host == "example.invalid")
        #expect(components.path == "/mobile-assignment/search")
        #expect(components.queryItems == [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "3")
        ])
        #expect(components.percentEncodedQuery?.contains("C%2B%2B") == true)
        #expect(components.fragment == nil)
    }

    @Test(arguments: ["https://example.invalid/api", "https://example.invalid/api/"])
    func preservesBasePath(baseURLString: String) async throws {
        let baseURL = try #require(URL(string: baseURLString))
        let stub = StubbedSession(response: .http(status: 200, data: Fixtures.emptyPage))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        _ = try await repository.search(query: "apple", page: 1)

        let request = try #require(stub.requests.first)
        #expect(request.url?.absoluteString == "https://example.invalid/api/search?query=apple&page=1")
    }

    @Test func returnsEmptyResults() async throws {
        let stub = StubbedSession(response: .http(status: 200, data: Fixtures.emptyPage))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        let result = try await repository.search(query: "missing", page: 1)

        #expect(result.products.isEmpty)
        #expect(result.totalResults == 0)
        #expect(result.nextPage == nil)
    }

    @Test(arguments: [(1, 3), (2, 1), (1, 0)])
    func rejectsUnexpectedPage(requestedPage: Int, returnedPage: Int) async {
        let data = Data("""
        {"products": [], "currentPage": \(returnedPage), "pageSize": 24, "totalResults": 70, "pageCount": 3}
        """.utf8)
        let stub = StubbedSession(response: .http(status: 200, data: data))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect(throws: ProductSearchAPIError.unexpectedPage(expected: requestedPage, actual: returnedPage)) {
            try await repository.search(query: "apple", page: requestedPage)
        }
    }

    @Test func rejectsRepeatedLastPageBeyondEnd() async throws {
        // Verified live: requesting page 4 returns the page-3 fixture unchanged.
        let stub = StubbedSession(response: .http(status: 200, data: try Fixtures.data(named: "product-search")))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect(throws: ProductSearchAPIError.unexpectedPage(expected: 4, actual: 3)) {
            try await repository.search(query: "apple", page: 4)
        }
    }

    @Test(arguments: [300, 400, 404, 429, 500])
    func rejectsUnsuccessfulHTTPStatus(status: Int) async {
        // Invalid JSON proves HTTP validation happens before decoding.
        let stub = StubbedSession(response: .http(status: status, data: Data("not JSON".utf8)))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect(throws: ProductSearchAPIError.httpStatus(status)) {
            try await repository.search(query: "apple", page: 1)
        }
    }

    @Test func rejectsNonHTTPResponse() async {
        let stub = StubbedSession(response: .nonHTTP(data: Fixtures.emptyPage))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect(throws: ProductSearchAPIError.nonHTTPResponse) {
            try await repository.search(query: "apple", page: 1)
        }
    }

    @Test(arguments: ["not JSON", ""])
    func rejectsMalformedResponse(body: String) async {
        // Malformed JSON remains an unwrapped dataCorrupted error.
        let stub = StubbedSession(response: .http(status: 200, data: Data(body.utf8)))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect {
            try await repository.search(query: "apple", page: 1)
        } throws: { error in
            guard case DecodingError.dataCorrupted(let context) = error else { return false }
            return context.codingPath.isEmpty
        }
    }

    @Test func propagatesMissingRequiredField() async {
        // Valid JSON with an incomplete schema remains an unwrapped keyNotFound error.
        let data = Data(#"{"products": [], "pageSize": 24, "totalResults": 0, "pageCount": 0}"#.utf8)
        let stub = StubbedSession(response: .http(status: 200, data: data))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect {
            try await repository.search(query: "apple", page: 1)
        } throws: { error in
            guard case DecodingError.keyNotFound(let key, let context) = error else { return false }
            return key.stringValue == "currentPage" && context.codingPath.isEmpty
        }
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .timedOut])
    func preservesTransportError(code: URLError.Code) async {
        let stub = StubbedSession(response: .failure(URLError(code)))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect {
            try await repository.search(query: "apple", page: 1)
        } throws: { error in
            (error as? URLError)?.code == code
        }
    }

    @Test func normalizesURLSessionCancellation() async {
        let stub = StubbedSession(response: .failure(URLError(.cancelled)))
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect(throws: CancellationError.self) {
            try await repository.search(query: "apple", page: 1)
        }
    }

    @Test(arguments: [0, -1])
    func rejectsInvalidPageWithoutRequest(page: Int) async {
        let stub = StubbedSession(response: .pending)
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        await #expect(throws: ProductSearchAPIError.invalidPage(page)) {
            try await repository.search(query: "apple", page: page)
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func respectsCancellationBeforeRequest() async {
        let stub = StubbedSession(response: .pending)
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await repository.search(query: "apple", page: 1)
        }
        defer { task.cancel() }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func cancelsInFlightRequest() async throws {
        let stub = StubbedSession(response: .pending)
        defer { stub.invalidate() }
        let repository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)
        let task = Task { try await repository.search(query: "apple", page: 1) }
        defer { task.cancel() }
        var started = stub.startedRequests.makeAsyncIterator()
        _ = try #require(await started.next())

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        var stopped = stub.stoppedRequests.makeAsyncIterator()
        #expect(await stopped.next() != nil)
    }

    @MainActor
    @Test func searchesThroughProtocolFromMainActor() async throws {
        // Verifies successful protocol use from a main-actor caller.
        let stub = StubbedSession(response: .http(status: 200, data: try Fixtures.data(named: "product-search")))
        defer { stub.invalidate() }
        let repository: any ProductSearchRepository = APIProductSearchRepository(baseURL: baseURL, session: stub.session)

        let result = try await repository.search(query: "apple", page: 3)

        #expect(result.products.count == 22)
    }
}
