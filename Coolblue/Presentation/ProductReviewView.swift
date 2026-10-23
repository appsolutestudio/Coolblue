import SwiftUI

struct ProductReviewView: View {
    let review: Product.Review
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var badgeSize: CGFloat = 16

    var body: some View {
        Group {
            if review.count == 0 {
                Text("No reviews")
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    ratingBadges
                    reviewCount
                }
            } else {
                HStack(spacing: 8) {
                    ratingBadges
                    reviewCount
                }
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

private extension ProductReviewView {
    var ratingBadges: some View {
        let fills = ProductReviewRating.badgeFills(for: review.average)
        return HStack(spacing: 2) {
            ForEach(fills.indices, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: badgeSize * 0.55, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: badgeSize, height: badgeSize)
                    .background {
                        Circle()
                            .fill(.secondary.opacity(0.25))
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(CoolblueColors.reviewGreen)
                                    .frame(width: badgeSize * fills[index])
                            }
                            .clipShape(Circle())
                    }
            }
        }
    }

    var reviewCount: Text {
        if review.count == 1 {
            Text("1 review")
        } else {
            Text("\(review.count, format: .number) reviews")
        }
    }

    var accessibilitySummary: Text {
        if review.count == 0 {
            Text("No reviews")
        } else {
            Text("Rated \(review.average, format: .number.precision(.fractionLength(0...1))) out of 10, \(reviewCount)")
        }
    }
}
