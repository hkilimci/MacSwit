//
//  MacSwitApp.swift
//  MacSwit
//
//  Created by Hasan Harun Kilimci on 23.01.2026.
//

import SwiftUI

@main
struct MacSwitApp: App {
    @StateObject private var appState: AppState

    init() {
        // Run migrations before initializing state
        SettingsMigration.runMigrations()
        _appState = StateObject(wrappedValue: AppState())
    }

    private var plugIcon: String {
        appState.isPlugOn ? "powerplug.fill" : "powerplug"
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(appState)
        } label: {
            Image(systemName: plugIcon)
                .font(.system(size: 16))
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
