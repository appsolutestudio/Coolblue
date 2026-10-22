nonisolated enum ProductSearchAPIError: Error, Equatable {
    case invalidPage(Int)
    case invalidURL
    case nonHTTPResponse
    case httpStatus(Int)
    case unexpectedPage(expected: Int, actual: Int)
}
