import Foundation

nonisolated struct APIProductSearchRepository: ProductSearchRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
    }
}

nonisolated extension APIProductSearchRepository {
    @concurrent
    func search(query: String, page: Int) async throws -> ProductSearchPage {
        try Task.checkCancellation()
        let request = try makeRequest(query: query, page: page)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }

        guard let response = response as? HTTPURLResponse else {
            throw ProductSearchAPIError.nonHTTPResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ProductSearchAPIError.httpStatus(response.statusCode)
        }

        let decoded = try JSONDecoder().decode(ProductSearchResponse.self, from: data)
        guard decoded.currentPage == page else {
            throw ProductSearchAPIError.unexpectedPage(expected: page, actual: decoded.currentPage)
        }

        let result = decoded.toDomain()
        try Task.checkCancellation()
        return result
    }

    private func makeRequest(query: String, page: Int) throws -> URLRequest {
        guard page > 0 else {
            throw ProductSearchAPIError.invalidPage(page)
        }

        guard var components = URLComponents(
            url: baseURL.appending(path: "search"), resolvingAgainstBaseURL: false
        ) else {
            throw ProductSearchAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page))
        ]
        // Some servers interpret a literal plus as a space in query parameters.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            throw ProductSearchAPIError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
