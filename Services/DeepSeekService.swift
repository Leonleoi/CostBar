// Services/DeepSeekService.swift
import Foundation

final class DeepSeekService: UsageServiceProtocol {
    let provider: AIProvider = .deepseek
    let config: ProviderConfig

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(config: ProviderConfig) {
        self.config = config
        self.session = URLSession.shared
    }

    func fetchBalance() async throws -> BalanceRecord {
        let url = URL(string: "\(config.baseURL)/user/balance")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        try APIHelper.validateResponse(data: data, response: response)

        let payload = try decoder.decode(DeepSeekBalanceResponse.self, from: data)
        let info = payload.balanceInfos.first

        return BalanceRecord(
            provider: .deepseek,
            totalBalance: Double(info?.totalBalance ?? "0") ?? 0,
            grantAmount: Double(info?.grantedBalance ?? "0"),
            toppedUpAmount: Double(info?.toppedUpBalance ?? "0"),
            currency: info?.currency ?? "CNY"
        )
    }

    func fetchUsage(startDate: Date, endDate: Date) async throws -> [UsageRecord] {
        // DeepSeek does not provide a usage history API.
        // Usage tracking must be done locally.
        throw UsageError.balanceNotSupported
    }

    func verifyConnection() async throws {
        let url = URL(string: "\(config.baseURL)/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        try APIHelper.validateResponse(data: data, response: response)
    }
}
