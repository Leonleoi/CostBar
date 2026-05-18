// ViewModels/SettingsViewModel.swift
import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var refreshInterval: TimeInterval = AppConstants.defaultRefreshInterval {
        didSet { onIntervalChange?(refreshInterval) }
    }
    @Published var showingAddProvider = false
    @Published var apiKeys: [AIProvider: String] = [:]

    var onIntervalChange: ((TimeInterval) -> Void)?

    init() {
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        refreshInterval = saved > 0 ? saved : AppConstants.defaultRefreshInterval
    }

    func saveRefreshInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
    }

    func loadAPIKey(for provider: AIProvider) -> String {
        (try? KeychainStorage().read(key: provider.rawValue)) ?? ""
    }
}
