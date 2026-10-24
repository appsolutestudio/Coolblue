# Coolblue

A SwiftUI app for searching and browsing products, with images, prices, reviews, pagination, and retry states.

## Requirements

Xcode 26.2 and iOS 26.2 or later. The project uses Swift 6 and has no third-party dependencies.

## Architecture

I used MVVM with lightweight Clean Architecture and constructor-based dependency injection, split into Domain, Data, and Presentation. The domain defines products and the repository interface. DTOs handle decoding and mapping in the data layer. The view model owns search and pagination state, leaving the views to render it.

Dependencies are passed through initializers. `AppDependencies` assembles each search screen's view model and repository, and selects the fake repository for UI tests in Debug builds. The base URL lives in `APIConfiguration`. A single app target keeps the structure straightforward for this scope.

The view model runs on `MainActor`. The repository uses `@concurrent` to handle requests, decoding, and mapping away from the main actor. Data types and mapping extensions are `nonisolated`, and each request creates its own decoder. Cancellation stops superseded work, while a generation check prevents late responses from changing the active search. Request tasks capture the view model weakly and are cancelled when it is released.

## Search behavior

Search starts after a 600 ms pause in typing. Whitespace is normalized, so adding a trailing space does not trigger another request. Clearing the field cancels pending work and resets the screen. Retries and pagination skip the typing delay. The keyboard's Search key dismisses the keyboard.

A new search replaces the results. Later pages append unique product IDs in server order. Loading stops at the reported page count or when a page adds no new products. A failed page keeps existing results and offers an explicit retry, without automatically repeating the request.

The search field sits at the bottom for easier reach and moves above the keyboard. Rows adapt to accessibility text sizes. Review labels announce the score and count, and missing or failed images show a placeholder.

## API observations and assumptions

The brief states that the mock returns the same products for every search term. The app displays those responses without local filtering. Requests send `query` and `page`, although the mock does not confirm the query parameter name.

On 22 October 2026, pages 1 to 3 returned 24, 24, and 22 products, with matching page numbers and stable totals of 70 products across 3 pages. Page 4 returned HTTP 200 with page 3's content. The repository rejects mismatched page numbers.

All 70 products had a complete review summary. Reviews are therefore required in both the DTO and domain model. This is an assumption about the mock, not a guarantee about a real catalog. A malformed required field fails the whole page. In production, I would confirm the schema and consider per-product decoding with logging for malformed records.

Prices use `Decimal`, with exact decoding tests for fractional values. EUR and a 10-point review scale are assumptions. The UI converts scores into five partially filled badges and announces the original score out of 10. Delivery information remains optional and is shown only when explicitly true.

## Verification and scope

Unit tests cover decoding, request construction, cancellation, stale responses, debounce, deduplication, and pagination retries. Ten UI tests use fixed scenarios for search, focus, clearing, empty results, retry flows, pagination, and low review scores. They avoid live network calls and layout-coordinate assertions.

Unit tests pass in a local harness. App and UI test sources compile and link, and Release sources type-check. The latest UI test fixes still need a final simulator run.

I kept the scope to search and browsing. Product details, a dedicated image cache, and error-specific messaging are left out.
