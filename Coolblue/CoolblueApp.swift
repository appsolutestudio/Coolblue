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
    private let repository = APIProductSearchRepository(
        baseURL: APIConfiguration.baseURL,
        session: .shared
    )

    var body: some Scene {
        WindowGroup {
            ProductSearchView(model: ProductSearchViewModel(repository: repository))
        }
    }
}
