// CostBar-kxApp.swift
import SwiftUI

@main
struct CostBar_kxApp: App {
    @StateObject private var dashboardVM = DashboardViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(dashboardVM)
        } label: {
            let label = dashboardVM.deepseekBalanceLabel
            if dashboardVM.showBalanceInMenuBar, !label.isEmpty {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 11, design: .monospaced))
                    Image(systemName: "chart.pie.fill")
                }
            } else {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 14))
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(dashboardVM)
        }
    }
}
