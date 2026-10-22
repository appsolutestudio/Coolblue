import Foundation
import Testing

nonisolated enum Fixtures {
    static let emptyPage = Data(
        #"{"products": [], "currentPage": 1, "pageSize": 24, "totalResults": 0, "pageCount": 0}"#.utf8
    )

    static func data(named name: String) throws -> Data {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"),
            "Missing JSON fixture: \(name)"
        )
        return try Data(contentsOf: url)
    }
}

private final class BundleToken {}
