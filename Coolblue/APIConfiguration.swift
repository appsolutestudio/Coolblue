import Foundation

nonisolated enum APIConfiguration {
    static let baseURL: URL = {
        guard let url = URL(string: "https://bdk0sta2n0.execute-api.eu-west-1.amazonaws.com/mobile-assignment") else {
            preconditionFailure("Invalid API base URL configuration")
        }
        return url
    }()
}
