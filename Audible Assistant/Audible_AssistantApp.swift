//
//  Audible_AssistantApp.swift
//  Audible Assistant
//
//  Created by Andrew Blumenthal on 12/5/23.
//

import SwiftUI

@main
struct Audible_AssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(width: 600, height: 1000)
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #endif
    }
}
