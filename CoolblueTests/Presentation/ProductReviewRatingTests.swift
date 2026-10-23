import Testing
@testable import Coolblue

struct ProductReviewRatingTests {
    @Test func oneOutOfTenFillsHalfOfTheFirstBadge() {
        #expect(ProductReviewRating.badgeFills(for: 1) == [0.5, 0, 0, 0, 0])
    }

    @Test func threeOutOfTenFillsOneAndAHalfBadges() {
        #expect(ProductReviewRating.badgeFills(for: 3) == [1, 0.5, 0, 0, 0])
    }

    @Test func fiveOutOfTenFillsTwoAndAHalfBadges() {
        #expect(ProductReviewRating.badgeFills(for: 5) == [1, 1, 0.5, 0, 0])
    }

    @Test func clampsScoresOutsideTheDisplayRange() {
        #expect(ProductReviewRating.badgeFills(for: -1) == [0, 0, 0, 0, 0])
        #expect(ProductReviewRating.badgeFills(for: 0) == [0, 0, 0, 0, 0])
        #expect(ProductReviewRating.badgeFills(for: 10) == [1, 1, 1, 1, 1])
        #expect(ProductReviewRating.badgeFills(for: 11) == [1, 1, 1, 1, 1])
    }
}
