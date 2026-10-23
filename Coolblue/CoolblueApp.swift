//
//  CoolblueApp.swift
//  Coolblue
//
//  Created by Nami on 22/10/2026.
//

import SwiftUI

@main
struct CoolblueApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ProductSearchView(model: dependencies.makeProductSearchViewModel())
        }
    }
}
