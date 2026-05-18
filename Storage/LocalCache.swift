// Storage/LocalCache.swift
import Foundation

final class LocalCache {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var cacheDirectory: URL? {
        guard let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = dir.appendingPathComponent(AppConstants.appName)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir
    }

    func saveUsageHistory(_ records: [UsageRecord], for provider: AIProvider) throws {
        guard let dir = cacheDirectory else { return }
        let file = dir.appendingPathComponent("usage_\(provider.rawValue).json")
        let data = try encoder.encode(records)
        try data.write(to: file)
    }

    func loadUsageHistory(for provider: AIProvider) throws -> [UsageRecord] {
        guard let dir = cacheDirectory else { return [] }
        let file = dir.appendingPathComponent("usage_\(provider.rawValue).json")
        guard fileManager.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return try decoder.decode([UsageRecord].self, from: data)
    }

    func saveConfig(_ configs: [ProviderConfig]) throws {
        guard let dir = cacheDirectory else { return }
        let file = dir.appendingPathComponent("provider_configs.json")
        // Strip API keys — those are in Keychain
        let safeConfigs = configs.map { c in
            ProviderConfig(provider: c.provider, apiKey: "", baseURL: c.baseURL)
        }
        let data = try encoder.encode(safeConfigs)
        try data.write(to: file)
    }

    func loadConfig() throws -> [ProviderConfig] {
        guard let dir = cacheDirectory else { return [] }
        let file = dir.appendingPathComponent("provider_configs.json")
        guard fileManager.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return try decoder.decode([ProviderConfig].self, from: data)
    }
}
