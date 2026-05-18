// Services/OpenAIService.swift
import Foundation

final class OpenAIService: UsageServiceProtocol {
    let provider: AIProvider = .openai
    let config: ProviderConfig

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(config: ProviderConfig) {
        self.config = config
        self.session = URLSession.shared
    }

    func fetchBalance() async throws -> BalanceRecord {
        let url = URL(string: "\(config.baseURL)\(AppConstants.OpenAI.balanceEndpoint)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try APIHelper.validateResponse(data: data, response: response)

        let balanceResp = try decoder.decode(OpenAISubscriptionResponse.self, from: data)
        return BalanceRecord(
            provider: .openai,
            totalBalance: balanceResp.hardLimitUsd ?? 0,
            currency: "USD"
        )
    }

    func fetchUsage(startDate: Date, endDate: Date) async throws -> [UsageRecord] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let start = df.string(from: startDate)
        let end = df.string(from: endDate)

        var components = URLComponents(string: "\(config.baseURL)\(AppConstants.OpenAI.usageEndpoint)")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end)
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try APIHelper.validateResponse(data: data, response: response)

        struct OpenAIUsageResponse: Codable {
            struct DailyCost: Codable {
                let timestamp: Int
                let cost: Double?
                let lineItems: [LineItem]?
            }
            struct LineItem: Codable {
                let name: String?
                let cost: Double?
            }
            let dailyCosts: [DailyCost]?
            let totalUsage: Double?
        }

        let usageResp = try decoder.decode(OpenAIUsageResponse.self, from: data)
        return usageResp.dailyCosts?.map { daily in
            UsageRecord(
                provider: .openai,
                promptTokens: 0,
                completionTokens: 0,
                cost: daily.cost ?? 0,
                currency: "USD"
            )
        } ?? []
    }
}
