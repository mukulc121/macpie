//
//  MacPieApp.swift
//  MacPie
//
//  Created by Mukul on 13/08/25.
//

import SwiftUI

@main
struct MacPieApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var splashController = SplashScreenController()

    var body: some Scene {
        MenuBarExtra("MacPie", systemImage: "circle.grid.2x2") {
            Button("Toggle Pie") { coordinator.togglePie() }
            Button("Preferences…") { coordinator.openPreferences() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.window)

        // Keep a tiny hidden window to keep the App alive in SwiftUI-only apps
        WindowGroup("MacPie") {
            ContentView()
                .frame(width: 1, height: 1)
                .hidden()
                .onAppear {
                    // Show splash screen and open preferences after a delay
                    showSplashAndPreferences()
                }
        }.windowStyle(.hiddenTitleBar)
    }
    
    private func showSplashAndPreferences() {
        // Show splash screen immediately and then open preferences
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            splashController.showSplash()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                coordinator.openPreferences()
            }
        }
    }
}
