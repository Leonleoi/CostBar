// Views/ProviderRowView.swift
import SwiftUI

struct ProviderRowView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    let config: ProviderConfig

    private var isNotSupported: Bool {
        guard let err = dashboardVM.errorMessages[config.provider] else { return false }
        return err.contains("not support")
    }

    private var hasData: Bool {
        dashboardVM.balances[config.provider] != nil || dashboardVM.usageSummaries[config.provider] != nil
    }

    private var isLoading: Bool {
        dashboardVM.balances[config.provider] == nil
            && dashboardVM.errorMessages[config.provider] == nil
            && dashboardVM.isRefreshing
    }

    private var needsAPIKey: Bool {
        config.apiKey.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: config.provider.iconName)
                .font(.title3)
                .foregroundColor(colorFromString(config.provider.tintColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(config.provider.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if isNotSupported {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }
                }

                if needsAPIKey {
                    Text("API key not configured")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if let balance = dashboardVM.balances[config.provider] {
                    let display = dashboardVM.displayBalance(for: balance)
                    Text("Balance: \(String(format: "%.2f", display.amount)) \(display.currency.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let summary = dashboardVM.usageSummaries[config.provider] {
                    Text("This month: \(String(format: "%.2f", summary.totalCostThisMonth)) \(summary.currency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isNotSupported {
                    Text("Connected — usage data not available via API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let error = dashboardVM.errorMessages[config.provider] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if !hasData && !isNotSupported && !isLoading && !needsAPIKey {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else if needsAPIKey {
                Text("Add Key")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if let balance = dashboardVM.balances[config.provider] {
                VStack(alignment: .trailing, spacing: 1) {
                    let display = dashboardVM.displayBalance(for: balance)
                    Text("\(String(format: "%.2f", display.amount))")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(display.currency.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private func colorFromString(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        default: return .gray
        }
    }
}
