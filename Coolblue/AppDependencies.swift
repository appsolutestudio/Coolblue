import Foundation

@MainActor
struct AppDependencies {
    func makeProductSearchViewModel() -> ProductSearchViewModel {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"] {
            guard let scenario = UITestProductSearchRepository.Scenario(rawValue: value) else {
                preconditionFailure("Unknown UI test scenario: \(value)")
            }
            let repository = UITestProductSearchRepository(scenario: scenario)
            if ProcessInfo.processInfo.environment["UI_TEST_REAL_DEBOUNCE"] == "1" {
                return ProductSearchViewModel(repository: repository)
            }
            return ProductSearchViewModel(repository: repository, debounceDuration: .zero)
        }
        #endif

        let repository = APIProductSearchRepository(baseURL: APIConfiguration.baseURL, session: .shared)
        return ProductSearchViewModel(repository: repository)
    }
}
