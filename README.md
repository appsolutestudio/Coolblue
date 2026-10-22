# Coolblue

My take on the Coolblue iOS assignment: a SwiftUI app for searching and browsing products.

## Requirements

- Xcode 26.2
- iOS 26.2 or later

The project uses Swift 6 language mode and has no third-party dependencies.

## Architecture and decisions

I chose MVVM to keep search behavior separate from the views. SwiftUI will handle presentation, while an `@Observable` view model will own the search state and coordinate requests. This gives the loading, error, and retry behavior a place to live that can be tested without launching the UI.

Dependencies will be passed through initializers. The view model will depend on a small search service interface, so tests can provide responses directly without making network calls. For an app this size, a dependency injection framework would add little value.

The app will stay in a single target, with files grouped by responsibility. Separate packages and extra layers can be useful in a larger codebase, but this assignment does not need them. The aim is to keep the boundaries clear and the code easy to follow.

### Platform and concurrency

The assignment does not specify a minimum iOS version. I chose iOS 26.2 to match the newest SDK installed for this project and use modern SwiftUI APIs without compatibility branches. The trade-off is that the app will not run on older iOS versions.

Swift 6 language mode enables compile-time concurrency checks. The view model will be isolated to the main actor, with asynchronous networking through `async/await`. Starting a new search will cancel the previous request and invalidate its result, so a late response cannot overwrite the current search.

### Search and product data

Search will run when the user submits a query. This keeps the interaction straightforward and avoids a request for every keystroke. Queries will be trimmed, and repeated submissions of the same in-flight query will not start another request.

Prices will use `Decimal` rather than `Double` because they represent money. Decoding tests will check values such as `24.99` against an exact decimal value to verify that precision survives the JSON response.

Product images will have a placeholder for missing URLs or failed loads. An unavailable image should not prevent someone from browsing the results.

I chose to start with Apple's frameworks. SwiftUI, Foundation, and URLSession cover the needs of this app without adding package dependencies.

## Current status

The project currently contains the initial app and test templates. The architecture above describes the approach chosen for the implementation. Product search is not implemented yet.
