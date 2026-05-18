// Views/MenuBarPopover.swift
import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("kx")
                    .font(.headline)
                Spacer()
                if dashboardVM.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Button { Task { await dashboardVM.refreshAll() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh now")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            // Summary
            HStack(spacing: 20) {
                SummaryItem(label: "Active APIs", value: "\(dashboardVM.activeProviderCount)")
                SummaryItem(label: "Monthly Cost", value: formatCurrency(dashboardVM.totalCostThisMonth))
                if let lastRefresh = dashboardVM.lastRefreshDate {
                    SummaryItem(label: "Updated", value: formatTimeAgo(lastRefresh))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()

            // Provider list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(dashboardVM.providers.filter { $0.isEnabled && !$0.apiKey.isEmpty }) { config in
                        ProviderRowView(config: config)
                    }
                }
                .padding(12)
            }
            .frame(minHeight: 100, maxHeight: 300)

            Divider()
            // Footer actions
            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 320)
    }

    private func formatCurrency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}

struct SummaryItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
        }
    }
}
