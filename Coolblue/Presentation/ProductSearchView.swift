import SwiftUI

struct ProductSearchView: View {
    @State private var model: ProductSearchViewModel
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    init(model: ProductSearchViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            // Keep the field outside the changing state branches so it retains focus.
            ZStack {
                searchContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                searchBar
            }
            .onChange(of: searchText) { _, newValue in
                model.search(query: newValue)
            }
        }
        .tint(CoolblueColors.contentBlue)
    }
}

private extension ProductSearchView {
    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CoolblueColors.brandBlue)
                .accessibilityHidden(true)

            TextField("Search products", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.vertical, 12)
                .accessibilityIdentifier("productSearchField")
                .onSubmit {
                    isSearchFocused = false
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("searchClearButton")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: 48)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CoolblueColors.brandBlue)
    }

    @ViewBuilder
    var searchContent: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView(
                "Search products",
                systemImage: "magnifyingglass",
                description: Text("Type a product name to search.")
            )
            .accessibilityIdentifier("searchInitialState")
        case .loading:
            ProgressView("Searching products…")
                .accessibilityIdentifier("searchLoading")
        case .results(let products):
            productList(products)
        case .empty:
            ContentUnavailableView.search(text: model.query)
                .accessibilityIdentifier("searchEmptyState")
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load products", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("searchError")
            } description: {
                Text("Results for “\(model.query)” couldn't be loaded. Please try again.")
            } actions: {
                Button("Try again") {
                    model.retrySearch()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("searchRetryButton")
            }
        }
    }

    func productList(_ products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Results for “\(model.query)”")
                .accessibilityIdentifier("searchResultsHeading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isHeader)

            List {
                ForEach(products) { product in
                    ProductRow(product: product)
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                }

                if model.paginationState != .idle || model.canLoadMore {
                    paginationFooter
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("productList")
        }
    }

    @ViewBuilder
    var paginationFooter: some View {
        switch model.paginationState {
        case .idle:
            if model.canLoadMore {
                Button("Load more products") {
                    model.loadNextPage()
                }
                .accessibilityIdentifier("loadMoreButton")
                .onAppear {
                    model.loadNextPage()
                }
            }
        case .loading:
            ProgressView("Loading more products…")
                .accessibilityIdentifier("paginationLoading")
        case .failed:
            VStack(spacing: 12) {
                Text("Couldn't load more products")
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    model.retryNextPage()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Try again, load more products")
                .accessibilityIdentifier("paginationRetryButton")
            }
        }
    }
}

#if DEBUG
#Preview {
    ProductSearchView(model: ProductSearchViewModel(repository: PreviewProductSearchRepository()))
}

private nonisolated struct PreviewProductSearchRepository: ProductSearchRepository {
    func search(query: String, page: Int) async throws -> ProductSearchPage {
        ProductSearchPage(
            products: [Product(
                id: 1,
                name: "Apple iPhone X 256GB Zilver",
                price: 1279,
                imageURL: nil,
                highlights: ["256 GB opslagcapaciteit", "5,8 inch Retina HD scherm", "iOS 11"],
                review: Product.Review(average: 9.2, count: 209),
                nextDayDelivery: true
            )],
            currentPage: 1,
            pageSize: 24,
            totalResults: 1,
            pageCount: 1
        )
    }
}
#endif
