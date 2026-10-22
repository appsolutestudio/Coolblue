import Foundation

nonisolated struct Product: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let price: Decimal
    let imageURL: URL?
    let highlights: [String]
    let review: Review
    let nextDayDelivery: Bool?

    struct Review: Equatable, Sendable {
        let average: Double
        let count: Int
    }
}
