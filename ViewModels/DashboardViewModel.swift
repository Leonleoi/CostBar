// ViewModels/DashboardViewModel.swift
import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var providers: [ProviderConfig] = []
    @Published var balances: [AIProvider: BalanceRecord] = [:]
    @Published var usageSummaries: [AIProvider: UsageSummary] = [:]
    @Published var usageHistory: [AIProvider: [UsageRecord]] = [:]
    @Published var isRefreshing = false
    @Published var lastRefreshDate: Date?
    @Published var errorMessages: [AIProvider: String] = [:]
    @Published var globalError: String?

    // Floating window & menu bar display
    @Published var showFloatingWindow = false {
        didSet {
            UserDefaults.standard.set(showFloatingWindow, forKey: "showFloatingWindow")
            if showFloatingWindow {
                floatingPanel?.show()
            } else {
                floatingPanel?.hide()
            }
        }
    }
    @Published var showBalanceInMenuBar = false {
        didSet {
            UserDefaults.standard.set(showBalanceInMenuBar, forKey: "showBalanceInMenuBar")
        }
    }
    @Published var preferredCurrency: CurrencyType = .cny {
        didSet {
            UserDefaults.standard.set(preferredCurrency.rawValue, forKey: "preferredCurrency")
            if preferredCurrency == .usd {
                fetchExchangeRate()
            }
        }
    }
    @Published var exchangeRate: Double?

    enum CurrencyType: String, CaseIterable, Identifiable {
        case cny = "CNY"
        case usd = "USD"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .cny: return "¥"
            case .usd: return "$"
            }
        }
    }

    var deepseekBalanceLabel: String {
        let (amount, currency) = displayDeepseekBalance
        guard let amount else { return "" }
        return String(format: "\(currency.symbol)%.1f", amount)
    }

    var displayDeepseekBalance: (amount: Double?, currency: CurrencyType) {
        guard let record = balances[.deepseek] else { return (nil, preferredCurrency) }
        let actualCurrency = record.currency.uppercased()
        // If user wants USD and balance is in CNY, convert
        if preferredCurrency == .usd, actualCurrency == "CNY", let rate = exchangeRate {
            let converted = record.totalBalance / rate
            return (converted, .usd)
        }
        // If user wants CNY and balance is in USD, convert
        if preferredCurrency == .cny, actualCurrency == "USD", let rate = exchangeRate {
            let converted = record.totalBalance * rate
            return (converted, .cny)
        }
        // Otherwise show in its original currency
        let type = CurrencyType(rawValue: actualCurrency) ?? preferredCurrency
        return (record.totalBalance, type)
    }

    private let keychain = KeychainStorage()
    private let cache = LocalCache()
    private let scheduler = RefreshScheduler()
    private var refreshTask: Task<Void, Never>?
    private var floatingPanel: FloatingPanelController?
    private let exchangeService = ExchangeRateService()

    var totalCostThisMonth: Double {
        usageSummaries.values.reduce(0) { $0 + $1.totalCostThisMonth }
    }

    var activeProviderCount: Int {
        providers.filter { $0.isEnabled && !$0.apiKey.isEmpty }.count
    }

    init() {
        loadProviders()
        setupDefaultProviders()
        loadCachedData()
        loadPreferences()
        floatingPanel = FloatingPanelController(dashboardVM: self)
        if showFloatingWindow { floatingPanel?.show() }
        startAutoRefresh()
    }

    private func loadPreferences() {
        showFloatingWindow = UserDefaults.standard.bool(forKey: "showFloatingWindow")
        showBalanceInMenuBar = UserDefaults.standard.bool(forKey: "showBalanceInMenuBar")
        if let raw = UserDefaults.standard.string(forKey: "preferredCurrency"),
           let currency = CurrencyType(rawValue: raw) {
            preferredCurrency = currency
        }
    }

    func fetchExchangeRate() {
        Task {
            do {
                let snapshot = try await exchangeService.fetchUSDCNYRate()
                exchangeRate = snapshot.rate
            } catch {
                // Exchange rate unavailable — will show CNY
            }
        }
    }

    private func setupDefaultProviders() {
        guard providers.isEmpty else { return }
        providers = [
            ProviderConfig(provider: .deepseek, baseURL: AppConstants.DeepSeek.baseURL),
            ProviderConfig(provider: .openai, baseURL: AppConstants.OpenAI.baseURL),
            ProviderConfig(provider: .anthropic, baseURL: AppConstants.Anthropic.baseURL)
        ]
        saveProviderConfigs()
    }

    private func loadProviders() {
        do {
            let configs = try cache.loadConfig()
            if !configs.isEmpty {
                self.providers = configs.map { cached in
                    // Try to load API key from Keychain
                    var config = cached
                    config.apiKey = (try? keychain.read(key: cached.provider.rawValue)) ?? ""
                    config.isEnabled = true
                    return config
                }
            }
        } catch {
            globalError = "Failed to load provider configs"
        }
    }

    private func loadCachedData() {
        for provider in AIProvider.allCases {
            usageHistory[provider] = (try? cache.loadUsageHistory(for: provider)) ?? []
        }
    }

    func refreshAll() async {
        isRefreshing = true
        globalError = nil
        errorMessages = [:]

        typealias ProviderResult = (provider: AIProvider, balance: BalanceRecord?, records: [UsageRecord]?, error: String?)
        let activeConfigs = providers.filter { $0.isEnabled && !$0.apiKey.isEmpty }

        let results: [ProviderResult] = await withTaskGroup(of: ProviderResult.self) { group in
            for config in activeConfigs {
                group.addTask {
                    let service = UsageServiceFactory.makeService(for: config)
                    var balance: BalanceRecord?
                    var records: [UsageRecord]?
                    var errorMsg: String?

                    do {
                        balance = try await service.fetchBalance()
                    } catch {
                        errorMsg = error.localizedDescription
                    }

                    if errorMsg == nil {
                        let end = Date()
                        let start = Calendar.current.date(byAdding: .day, value: -30, to: end)!
                        do {
                            records = try await service.fetchUsage(startDate: start, endDate: end)
                        } catch {
                            errorMsg = error.localizedDescription
                        }
                    }

                    return (config.provider, balance, records, errorMsg)
                }
            }

            var collected: [ProviderResult] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for result in results {
            balances[result.provider] = result.balance
            errorMessages[result.provider] = result.error

            if let records = result.records {
                usageHistory[result.provider] = records
                let totalCost = records.reduce(0) { $0 + $1.cost }
                let totalTokens = records.reduce(0) { $0 + $1.totalTokens }
                usageSummaries[result.provider] = UsageSummary(
                    provider: result.provider,
                    totalTokensThisMonth: totalTokens,
                    totalCostThisMonth: totalCost,
                    currency: records.first?.currency ?? "USD",
                    lastUpdated: Date()
                )
                try? cache.saveUsageHistory(records, for: result.provider)
            }
        }

        // Fetch exchange rate if USD display is preferred
        if preferredCurrency == .usd {
            do {
                let snapshot = try await exchangeService.fetchUSDCNYRate()
                exchangeRate = snapshot.rate
            } catch {
                // Will show CNY if rate unavailable
            }
        }

        isRefreshing = false
        lastRefreshDate = Date()
    }

    func startAutoRefresh(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        refreshTask?.cancel()
        refreshTask = Task {
            // Immediate first refresh
            await refreshAll()
            // Then periodic
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await refreshAll()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func updateAPIKey(for provider: AIProvider, key: String) {
        guard let index = providers.firstIndex(where: { $0.provider == provider }) else { return }
        providers[index].apiKey = key
        try? keychain.save(key: provider.rawValue, value: key)
    }

    private func saveProviderConfigs() {
        try? cache.saveConfig(providers)
    }

    deinit {
        refreshTask?.cancel()
    }
}
