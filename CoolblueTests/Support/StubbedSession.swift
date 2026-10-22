import Foundation
import Synchronization

nonisolated final class StubbedSession: Sendable {
    enum Response: Sendable {
        case http(status: Int, data: Data)
        case nonHTTP(data: Data)
        case failure(URLError)
        case pending
    }

    let session: URLSession
    let startedRequests: AsyncStream<URLRequest>
    /// Emits stopLoading callbacks, which can also follow successful completion.
    let stoppedRequests: AsyncStream<Void>

    private let id: String
    private let history = Mutex<[URLRequest]>([])
    private let startedContinuation: AsyncStream<URLRequest>.Continuation
    private let stoppedContinuation: AsyncStream<Void>.Continuation

    init(response: Response) {
        id = UUID().uuidString
        (startedRequests, startedContinuation) = AsyncStream.makeStream(of: URLRequest.self)
        (stoppedRequests, stoppedContinuation) = AsyncStream.makeStream(of: Void.self)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        // Isolate parallel test sessions without changing the request URL.
        configuration.httpAdditionalHeaders = ["X-Test-ID": id]
        session = URLSession(configuration: configuration)

        StubURLProtocol.register(id: id, stub: .init(
            response: response,
            onStart: { [weak self] request in
                self?.history.withLock { $0.append(request) }
                self?.startedContinuation.yield(request)
            },
            onStop: { [weak self] in
                self?.stoppedContinuation.yield(())
            }
        ))
    }
}

nonisolated extension StubbedSession {
    var requests: [URLRequest] {
        history.withLock { $0 }
    }

    func invalidate() {
        session.invalidateAndCancel()
        StubURLProtocol.remove(id: id)
        startedContinuation.finish()
        stoppedContinuation.finish()
    }
}

// URLProtocol inherits unchecked sendability from Foundation. The only shared
// mutable state here is the registry, protected by a mutex and keyed per session.
private nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        let response: StubbedSession.Response
        let onStart: @Sendable (URLRequest) -> Void
        let onStop: @Sendable () -> Void
    }

    private static let registry = Mutex<[String: Stub]>([:])
}

nonisolated extension StubURLProtocol {
    static func register(id: String, stub: Stub) {
        registry.withLock { $0[id] = stub }
    }

    static func remove(id: String) {
        registry.withLock { _ = $0.removeValue(forKey: id) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let stub, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        stub.onStart(request)

        switch stub.response {
        case .http(let status, let data):
            guard let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: nil
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            finish(response: response, data: data)
        case .nonHTTP(let data):
            let response = URLResponse(url: url, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil)
            finish(response: response, data: data)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .pending:
            break
        }
    }

    override func stopLoading() {
        stub?.onStop()
    }

    private var stub: Stub? {
        guard let id = request.value(forHTTPHeaderField: "X-Test-ID") else { return nil }
        return Self.registry.withLock { $0[id] }
    }

    private func finish(response: URLResponse, data: Data) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
