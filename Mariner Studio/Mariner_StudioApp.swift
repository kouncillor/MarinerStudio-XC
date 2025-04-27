//
//  Mariner_StudioApp.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 4/25/25.
//

import SwiftUI

@main
struct Mariner_StudioApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.light) // Force light mode
        }
    }
}
