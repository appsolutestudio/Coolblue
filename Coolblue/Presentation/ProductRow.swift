import SwiftUI

struct ProductRow: View {
    let product: Product
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    productImage
                    productDetails
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    productImage
                    productDetails
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("product-\(product.id)")
    }
}

private extension ProductRow {
    var productImage: some View {
        Group {
            if let url = product.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFit().padding(8)
                    case .failure:
                        imagePlaceholder
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(width: 96, height: 112)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    var imagePlaceholder: some View {
        Image(systemName: "photo")
            .font(.title)
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var productDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.name)
                .font(.headline)
                .foregroundStyle(CoolblueColors.contentBlue)

            ProductReviewView(review: product.review)

            Text(product.price, format: .currency(code: "EUR"))
                .font(.title3.bold())

            ForEach(product.highlights.indices, id: \.self) { index in
                Label(product.highlights[index], systemImage: "checkmark")
                    .font(.caption)
            }

            if product.nextDayDelivery == true {
                Label {
                    Text("Next-day delivery")
                } icon: {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    ProductRow(product: Product(
        id: 1,
        name: "Apple iPhone X 256GB Zilver",
        price: 1279,
        imageURL: nil,
        highlights: ["256 GB opslagcapaciteit", "5,8 inch Retina HD scherm", "iOS 11"],
        review: Product.Review(average: 9.2, count: 209),
        nextDayDelivery: true
    ))
    .padding()
}
