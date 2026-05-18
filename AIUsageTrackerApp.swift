// AIUsageTrackerApp.swift
import SwiftUI

@main
struct AIUsageTrackerApp: App {
    @StateObject private var dashboardVM = DashboardViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(dashboardVM)
        } label: {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 14))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(dashboardVM)
        }
    }
}
