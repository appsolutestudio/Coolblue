import XCTest

final class CoolblueUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSearchShowsProductsWithoutSubmitting() {
        let app = launch(usesRealDebounce: true)
        XCTAssertTrue(element("searchInitialState", in: app).waitForExistence(timeout: 5))

        search("phone", in: app)

        let firstProduct = element("product-1", in: app)
        XCTAssertTrue(firstProduct.waitForExistence(timeout: 5))
        XCTAssertTrue(firstProduct.label.contains("Test phone 1"))
        assertResultsHeading(for: "phone", in: app)
        let searchField = app.textFields["productSearchField"]
        XCTAssertEqual(searchField.value as? String, "phone")
        assertHittable(firstProduct)
        assertHittable(searchField)
        XCTAssertTrue(firstProduct.label.contains("Rated 9.2 out of 10"))
    }

    @MainActor
    func testSearchKeepsFocusAcrossInputAndResultChanges() {
        let app = launch(usesRealDebounce: true)
        let searchField = app.textFields["productSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        var query = ""
        for character in ["p", "h", "o", "n", "e"] {
            // Deliberately do not tap again between input or completed searches.
            searchField.typeText(character)
            query += character
            assertResultsHeading(for: query, in: app)
            XCTAssertEqual(searchField.value as? String, query)
        }
    }

    @MainActor
    func testOneOutOfTenReview() {
        assertLowRating(scenario: "rating1", score: 1)
    }

    @MainActor
    func testThreeOutOfTenReview() {
        assertLowRating(scenario: "rating3", score: 3)
    }

    @MainActor
    func testFiveOutOfTenReview() {
        assertLowRating(scenario: "rating5", score: 5)
    }

    @MainActor
    func testClearingSearchReturnsToInitialState() {
        let app = launch()
        search("phone", in: app)
        XCTAssertTrue(element("product-1", in: app).waitForExistence(timeout: 5))

        let searchField = app.textFields["productSearchField"]
        searchField.tap()
        let clearButton = app.buttons["searchClearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.tap()

        XCTAssertTrue(element("searchInitialState", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("productList", in: app).exists)
    }

    @MainActor
    func testEmptySearchShowsEmptyState() {
        let app = launch(scenario: "empty")
        search("missing", in: app)

        XCTAssertTrue(element("searchEmptyState", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("productList", in: app).exists)
        XCTAssertFalse(app.buttons["searchRetryButton"].exists)
    }

    @MainActor
    func testFailedSearchCanBeRetried() {
        let app = launch(scenario: "searchRetry")
        search("phone", in: app)

        XCTAssertTrue(app.staticTexts["searchError"].waitForExistence(timeout: 5))
        let retry = app.buttons["searchRetryButton"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "searchRetryButton").count, 1)
        assertHittable(retry)
        retry.tap()

        XCTAssertTrue(element("product-1", in: app).waitForExistence(timeout: 5))
        assertResultsHeading(for: "phone", in: app)
        XCTAssertFalse(app.buttons["searchRetryButton"].exists)
    }

    @MainActor
    func testScrollingLoadsTheLastPage() {
        let app = launch()
        search("phone", in: app)
        XCTAssertTrue(element("product-1", in: app).waitForExistence(timeout: 5))
        dismissKeyboard(in: app)

        let lastProduct = element("product-14", in: app)
        scrollTo(lastProduct, in: app)

        XCTAssertTrue(lastProduct.label.contains("Test phone 14"))
        XCTAssertFalse(app.buttons["loadMoreButton"].exists)
        XCTAssertFalse(element("paginationLoading", in: app).exists)
        XCTAssertFalse(app.buttons["paginationRetryButton"].exists)
    }

    @MainActor
    func testFailedNextPageRetainsProductsAndCanBeRetried() {
        let app = launch(scenario: "paginationRetry")
        search("phone", in: app)
        let firstProduct = element("product-1", in: app)
        XCTAssertTrue(firstProduct.waitForExistence(timeout: 5))
        dismissKeyboard(in: app)

        let retry = app.buttons["paginationRetryButton"]
        scrollTo(retry, in: app)

        // A failed page keeps the previous products and waits for an explicit retry.
        scrollTo(firstProduct, in: app, swipingDown: true)
        XCTAssertTrue(firstProduct.label.contains("Test phone 1"))
        scrollTo(retry, in: app)
        retry.tap()

        scrollTo(element("product-14", in: app), in: app)
        XCTAssertFalse(app.buttons["paginationRetryButton"].exists)
        XCTAssertFalse(app.buttons["loadMoreButton"].exists)
    }
}

@MainActor
private extension CoolblueUITests {
    func assertResultsHeading(
        for query: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let heading = app.staticTexts["searchResultsHeading"]
        let predicate = NSPredicate(format: "exists == true AND label CONTAINS %@", query)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: heading)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
            "Expected a results heading for \(query)", file: file, line: line
        )
    }

    func assertHittable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
            "Expected \(element) to become hittable", file: file, line: line
        )
    }

    func assertLowRating(scenario: String, score: Int, file: StaticString = #filePath, line: UInt = #line) {
        let app = launch(scenario: scenario)
        search("phone", in: app)
        let product = element("product-1", in: app)
        XCTAssertTrue(product.waitForExistence(timeout: 5), file: file, line: line)
        dismissKeyboard(in: app)
        XCTAssertTrue(product.label.contains("Rated \(score) out of 10"), file: file, line: line)
        XCTAssertTrue(product.label.contains("42 reviews"), file: file, line: line)

        // Keep the rendered badges as evidence alongside the score assertions.
        let screenshot = XCTAttachment(screenshot: product.screenshot())
        screenshot.name = "Review \(score) out of 10"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func launch(scenario: String = "results", usesRealDebounce: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        if usesRealDebounce {
            app.launchEnvironment["UI_TEST_REAL_DEBOUNCE"] = "1"
        }
        app.launch()
        return app
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func search(_ query: String, in app: XCUIApplication) {
        let searchField = app.textFields["productSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(query)
    }

    func dismissKeyboard(in app: XCUIApplication) {
        let searchKey = app.keyboards.buttons["Search"]
        if searchKey.exists {
            searchKey.tap()
        }
    }

    func scrollTo(
        _ target: XCUIElement,
        in app: XCUIApplication,
        swipingDown: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let list = element("productList", in: app)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(30))
        // Larger text and smaller screens may need more swipes to reach the same product.
        while clock.now < deadline {
            if target.waitForExistence(timeout: 0.5), target.isHittable {
                return
            }
            if swipingDown {
                list.swipeDown()
            } else {
                list.swipeUp()
            }
        }
        XCTAssertTrue(target.exists && target.isHittable, "Couldn't scroll to \(target)", file: file, line: line)
    }
}
