# Coolblue

My take on the Coolblue iOS assignment: a SwiftUI app for searching and browsing products.

## Requirements

- Xcode 26.2
- iOS 26.2 or later

The project uses Swift 6 language mode and has no third-party dependencies.

## Architecture and decisions

I chose a small Clean Architecture structure with MVVM for presentation. The domain owns the product model without depending on SwiftUI or the API response format. The data layer decodes the API response and maps it into that model. MVVM keeps search behavior separate from the views. SwiftUI will handle presentation, while an `@Observable` view model will own the search state and coordinate requests. This gives the loading, error, and retry behavior a place to live that can be tested without launching the UI.

Dependencies will be passed through initializers. The view model will depend on a small search service interface, so tests can provide responses directly without making network calls. For an app this size, a dependency injection framework would add little value.

The app will stay in a single target, with files grouped by responsibility. Separate packages and extra layers can be useful in a larger codebase, but this assignment does not need them. The aim is to keep the boundaries clear and the code easy to follow.

### Platform and concurrency

The assignment does not specify a minimum iOS version. I chose iOS 26.2 to match the newest SDK installed for this project and use modern SwiftUI APIs without compatibility branches. The trade-off is that the app will not run on older iOS versions.

Swift 6 language mode enables compile-time concurrency checks. The view model will be isolated to the main actor, with asynchronous networking through `async/await`. Starting a new search will cancel the previous request and invalidate its result, so a late response cannot overwrite the current search.

### Search and product data

Search will run when the user submits a query. This keeps the interaction straightforward and avoids a request for every keystroke. Queries will be trimmed, and repeated submissions of the same in-flight query will not start another request.

Prices use `Decimal` rather than `Double` because they represent money. Decoding tests compare `24.99` and `1042.99` against exact decimal values, including both prices in the supplied response fixture.

The DTO requires an ID, name, price, and a complete review summary, matching the supplied response. The domain model also requires a review, so the same expectation holds from decoding through mapping. A summary with a count of zero represents no reviews. If a record cannot decode those fields, the request fails rather than quietly showing an incomplete list. Optional fields may be absent or null, but a present value with the wrong type still fails decoding. Missing delivery information stays unknown, so the UI can omit the delivery claim instead of treating it as unavailable.

Image URLs must be absolute HTTP or HTTPS URLs with a host. This filters out relative paths and local file URLs before they reach the image loader. It does not guarantee that an image can be downloaded.

Product images will have a placeholder for missing URLs or failed loads. An unavailable image should not prevent someone from browsing the results.

I chose to start with Apple's frameworks. SwiftUI, Foundation, and URLSession cover the needs of this app without adding package dependencies.

## Current status

The product model and API response mapping are implemented, with decoding tests for prices, required fields, optional details, and image URLs. The screen is still the initial template. Networking and the search view model are next.
