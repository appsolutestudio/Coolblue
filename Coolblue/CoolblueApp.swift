//
//  CoolblueApp.swift
//  Coolblue
//
//  Created by Nami on 22/10/2026.
//

import Foundation
import SwiftUI

@main
struct CoolblueApp: App {
    var body: some Scene {
        WindowGroup {
            ProductSearchView(model: Self.makeSearchViewModel())
        }
    }
}

private extension CoolblueApp {
    static func makeSearchViewModel() -> ProductSearchViewModel {
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
