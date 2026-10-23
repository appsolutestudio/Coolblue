nonisolated enum ProductReviewRating {
    static func badgeFills(for average: Double) -> [Double] {
        let stars = min(max(average / 2, 0), 5)
        return (0..<5).map { index in
            min(max(stars - Double(index), 0), 1)
        }
    }
}
