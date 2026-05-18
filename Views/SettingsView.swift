// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @StateObject private var settingsVM = SettingsViewModel()
    @State private var apiKeyInputs: [AIProvider: String] = [:]
    @State private var testingProvider: AIProvider?
    @State private var testResults: [AIProvider: String] = [:]

    var body: some View {
        TabView {
            Form {
                Section("API Keys") {
                    ForEach(AIProvider.allCases) { provider in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.rawValue)
                                .font(.headline)
                            SecureField("API Key", text: Binding(
                                get: { apiKeyInputs[provider] ?? "" },
                                set: {
                                    apiKeyInputs[provider] = $0
                                    testResults[provider] = nil
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                apiKeyInputs[provider] = dashboardVM.providers.first(where: { $0.provider == provider })?.apiKey ?? ""
                            }

                            HStack {
                                Button("Save") {
                                    dashboardVM.updateAPIKey(for: provider, key: apiKeyInputs[provider] ?? "")
                                    testResults[provider] = "Saved"
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                if testingProvider == provider {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 60)
                                } else {
                                    Button("Test Connection") {
                                        testConnection(provider: provider)
                                    }
                                    .controlSize(.small)
                                    .disabled(apiKeyInputs[provider]?.isEmpty ?? true)
                                }

                                if let result = testResults[provider] {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(result == "Saved" || result == "Success" ? .green : .red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Display") {
                    Toggle(isOn: Binding(
                        get: { dashboardVM.showFloatingWindow },
                        set: { dashboardVM.showFloatingWindow = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Floating Widget")
                                .font(.subheadline)
                            Text("Always-on-top balance widget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { dashboardVM.showBalanceInMenuBar },
                        set: { dashboardVM.showBalanceInMenuBar = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Balance in Menu Bar")
                                .font(.subheadline)
                            Text("Display balance next to the menu bar icon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Picker("Currency", selection: Binding(
                        get: { dashboardVM.preferredCurrency },
                        set: { dashboardVM.preferredCurrency = $0 }
                    )) {
                        Text("CNY ¥").tag(DashboardViewModel.CurrencyType.cny)
                        Text("USD $").tag(DashboardViewModel.CurrencyType.usd)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Refresh Settings") {
                    Slider(value: Binding(
                        get: { settingsVM.refreshInterval },
                        set: { newVal in
                            settingsVM.refreshInterval = newVal
                            settingsVM.saveRefreshInterval()
                        }
                    ), in: AppConstants.minRefreshInterval...AppConstants.maxRefreshInterval, step: 30) {
                        Text("Refresh Interval")
                    }
                    Text("Auto-refresh every \(Int(settingsVM.refreshInterval / 60)) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .padding()

            UsageChartView(
                records: dashboardVM.usageHistory.values.flatMap { $0 },
                providerName: "All"
            )
            .tabItem { Label("Charts", systemImage: "chart.bar") }
            .padding()
        }
        .frame(width: 480, height: 520)
    }

    private func testConnection(provider: AIProvider) {
        testingProvider = provider
        testResults[provider] = nil
        dashboardVM.errorMessages[provider] = nil

        Task {
            defer { testingProvider = nil }

            let key = apiKeyInputs[provider] ?? ""
            guard !key.isEmpty else {
                testResults[provider] = "Please enter an API key"
                return
            }

            let config = ProviderConfig(provider: provider, apiKey: key)
            let service = UsageServiceFactory.makeService(for: config)

            do {
                try await service.verifyConnection()
                testResults[provider] = "Success"
                dashboardVM.errorMessages[provider] = nil
            } catch {
                let msg = error.localizedDescription
                testResults[provider] = msg
                dashboardVM.errorMessages[provider] = "Connection failed: \(msg)"
            }
        }
    }
}
