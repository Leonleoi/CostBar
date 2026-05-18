// Services/AnthropicService.swift
import Foundation

final class AnthropicService: UsageServiceProtocol {
    let provider: AIProvider = .anthropic
    let config: ProviderConfig

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(config: ProviderConfig) {
        self.config = config
        self.session = URLSession.shared
    }

    func fetchBalance() async throws -> BalanceRecord {
        throw UsageError.balanceNotSupported
    }

    func verifyConnection() async throws {
        let url = URL(string: "\(config.baseURL)/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("\(config.apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, response) = try await session.data(for: request)
        try APIHelper.validateResponse(data: data, response: response)
    }

    func fetchUsage(startDate: Date, endDate: Date) async throws -> [UsageRecord] {
        let url = URL(string: "\(config.baseURL)\(AppConstants.Anthropic.usageEndpoint)")!
        var request = URLRequest(url: url)
        request.setValue("\(config.apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await session.data(for: request)
        try APIHelper.validateResponse(data: data, response: response)

        struct AnthropicUsageResponse: Codable {
            let data: [UsageItem]?
            struct UsageItem: Codable {
                let inputTokens: Int?
                let outputTokens: Int?
                let cost: Double?
            }
        }

        let usageResp = try decoder.decode(AnthropicUsageResponse.self, from: data)
        return usageResp.data?.map { item in
            UsageRecord(
                provider: .anthropic,
                promptTokens: item.inputTokens ?? 0,
                completionTokens: item.outputTokens ?? 0,
                cost: item.cost ?? 0,
                currency: "USD"
            )
        } ?? []
    }
}

enum UsageError: LocalizedError {
    case balanceNotSupported

    var errorDescription: String? {
        switch self {
        case .balanceNotSupported: return "This provider does not support balance queries"
        }
    }
}
