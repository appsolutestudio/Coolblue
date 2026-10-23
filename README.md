# Coolblue

My take on the Coolblue iOS assignment: a SwiftUI app for searching and browsing products.

## Requirements

- Xcode 26.2
- iOS 26.2 or later

The project uses Swift 6 language mode and has no third-party dependencies.

## Architecture and decisions

I chose a small Clean Architecture structure with MVVM for presentation. The domain owns the product model without depending on SwiftUI or the API response format. The data layer decodes the API response and maps it into that model. MVVM keeps search behavior separate from the views. An `@Observable` view model owns the search state and coordinates requests, leaving presentation to SwiftUI. This gives the loading, error, and retry behavior a place to live that can be tested without launching the UI.

Dependencies are passed through initializers. The view model depends on a small repository interface in the domain layer, so tests can provide responses directly without making network calls. The data layer implements that interface with an injected base URL and `URLSession`, and returns domain products with their page metadata. The production base URL lives in `APIConfiguration`. The repository only adds the search path and query parameters, while tests supply a dummy host. For an app this size, a dependency injection framework would add little value.

The app will stay in a single target, with files grouped by responsibility. Separate packages and extra layers can be useful in a larger codebase, but this assignment does not need them. The aim is to keep the boundaries clear and the code easy to follow.

### Platform and concurrency

The assignment does not specify a minimum iOS version. I chose iOS 26.2 to match the newest SDK installed for this project and use modern SwiftUI APIs without compatibility branches. The trade-off is that the app will not run on older iOS versions.

Swift 6 language mode enables compile-time concurrency checks. The view model is isolated to the main actor. The repository uses `@concurrent` so request handling, decoding, and mapping run on the generic executor even when called from the main actor. Each request creates its own decoder. The data types and mapping extensions are explicitly `nonisolated`.

Cancellation is checked before starting a request and before returning the mapped result. URLSession handles cancellation while awaiting the network response. URLSession cancellation is converted to `CancellationError`, giving callers one cancellation case to handle. Other transport errors and decoding errors pass through without being replaced. Starting a new search cancels the previous request and invalidates its result in the view model, so a late response cannot overwrite the current search.

The view model owns the request task, which captures it weakly so a pending request does not keep the screen's model alive. Explicit cancellation clears loading indicators while retaining loaded products and any existing retry state. Releasing the model also cancels its request. Cancellation does not produce an error state.

### Search and product data

Search runs when the user submits a query. This keeps the interaction straightforward and avoids a request for every keystroke. The view model trims submitted queries, and repeated submissions of the same in-flight query do not start another request. Submitting a blank query clears the search without a request. The submitted query belongs to the view model, while the view will own the editable search text.

Prices use `Decimal` rather than `Double` because they represent money. Decoding tests compare `24.99` and `1042.99` against exact decimal values, including both prices in the supplied response fixture.

The DTO requires an ID, name, price, and a complete review summary. The domain model also requires a review, so that expectation holds through mapping.

On 22 October 2026, I checked all three live pages, containing 24, 24, and 22 products. All 70 unique products included `reviewInformation.reviewSummary`, a numeric `reviewAverage`, and an integer `reviewCount`. None had a review count of zero. This supports the strict model for the current mock data. It remains an assumption about the schema, not a guarantee about real catalog data or products without reviews.

One malformed required field fails the whole page. For an initial search, the result is an error state instead of a partial product list. This is deliberate for the assignment: report bad data rather than silently hide it. A later-page failure retains products already loaded and allows a retry for the failed page.

In production, I would confirm the schema first and model absent review data explicitly if the API permits it. For malformed records, I would consider decoding products individually with logging and monitoring, so valid products remain available and discarded records are visible to the team.

Optional fields may be absent or null, but a present value with the wrong type still fails decoding. Missing delivery information stays unknown, so the UI can omit the delivery claim instead of treating it as unavailable.

Image URLs must be absolute HTTP or HTTPS URLs with a host. This filters out relative paths and local file URLs before they reach the image loader. It does not guarantee that an image can be downloaded.

Product images will have a placeholder for missing URLs or failed loads. An unavailable image should not prevent someone from browsing the results.

I chose to start with Apple's frameworks. SwiftUI, Foundation, and URLSession cover the needs of this app without adding package dependencies.

### Search API

Requests use GET with `query` and `page` parameters. The name `query` is an assumption because the supplied URL is incomplete and the mock does not distinguish between search terms or validate that parameter name. Search filtering therefore remains unverified.

On 22 October 2026, live requests for pages 1, 2, and 3 returned matching `currentPage` values and 24, 24, and 22 products respectively. `totalResults` stayed at 70 and `pageCount` stayed at 3. The client starts at page 1 and always sends an explicit page number. A previous request without a page returned page 3.

`ProductSearchPage.nextPage` stops at the reported page count, so the client does not need to probe beyond the last page. The repository rejects a response whose `currentPage` differs from the requested page. Pagination totals were stable in the captured responses, but the repository does not assume they remain fixed across requests. On the same date, requesting page 4 returned HTTP 200 with the exact page-3 response, including `currentPage: 3` and the same 22 products. The page-number guard rejects that response if page 4 is requested.

The repository keeps no accumulated results or pagination state. The view model handles that:

- Keep the first occurrence of each product ID in server order, removing duplicates both within a page and across previously loaded pages.
- Stop automatic loading without showing an error when a successful page adds no new products.
- Request page 1 for a new search, then request further pages only through `nextPage`.
- Pause automatic loading after any failed page request, keep existing products, and show a retry control for that page only. Loading resumes only after an explicit retry or a new search.
- Ignore both success and failure responses from an invalidated search generation, including an earlier search with the same query.
- Advance pagination only after accepting a successful response.

An `unexpectedPage` error follows the same failure path as other request failures. An initial-search failure sets the error state. A later-page failure sets a separate pagination error state without discarding the current list. The screen will show “Couldn't load more products” with a retry control for that state. The view model does not switch on the data layer's error enum. A repeated failure remains available for manual retry and does not trigger an automatic retry loop. With the verified page count of 3, normal pagination does not request page 4.

Search requests have a 30-second inactivity timeout, a deliberate limit for this screen rather than relying on the 60-second default. This is not a strict deadline for the entire operation. The timeout is set on the request so it also applies to the injected session without changing how that session is created or owned.

Networking tests use an ephemeral URLSession with a custom URLProtocol. Each session has its own stub registration, with shared state protected by a mutex so tests can run in parallel. Cancellation tests wait for request callbacks rather than relying on delays.

## Current status

The domain models, API mapping, search repository, and search view model are implemented. Tests cover decoding, requests, failures, cancellation, ordered deduplication, pagination retries, and stale responses. View model tests use a small controllable repository that deliberately allows late responses after cancellation. This checks behavior without network timing or sleeps. The screen is still the initial template. Connecting the view model to the search UI is next.
