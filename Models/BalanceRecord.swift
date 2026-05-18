// Models/BalanceRecord.swift
import Foundation

struct BalanceRecord: Codable, Identifiable {
    let id: UUID
    let provider: AIProvider
    let timestamp: Date
    let totalBalance: Double
    let grantAmount: Double?
    let toppedUpAmount: Double?
    let totalUsed: Double
    let currency: String

    init(
        provider: AIProvider,
        totalBalance: Double,
        grantAmount: Double? = nil,
        toppedUpAmount: Double? = nil,
        totalUsed: Double = 0,
        currency: String = "USD"
    ) {
        self.id = UUID()
        self.provider = provider
        self.timestamp = Date()
        self.totalBalance = totalBalance
        self.grantAmount = grantAmount
        self.toppedUpAmount = toppedUpAmount
        self.totalUsed = totalUsed
        self.currency = currency
    }
}

// MARK: - DeepSeek balance response
// GET https://api.deepseek.com/user/balance
// {
//   "is_available": true,
//   "balance_infos": [{
//     "currency": "CNY",
//     "total_balance": "10.50",
//     "granted_balance": "5.00",
//     "topped_up_balance": "5.50"
//   }]
// }
struct DeepSeekBalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    struct BalanceInfo: Codable {
        let currency: String
        let totalBalance: String
        let grantedBalance: String
        let toppedUpBalance: String

        enum CodingKeys: String, CodingKey {
            case currency
            case totalBalance = "total_balance"
            case grantedBalance = "granted_balance"
            case toppedUpBalance = "topped_up_balance"
        }
    }

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

// MARK: - OpenAI subscription response
// GET https://api.openai.com/dashboard/billing/subscription
// { "hard_limit_usd": 120, "soft_limit_usd": 100 }
struct OpenAISubscriptionResponse: Codable {
    let hardLimitUsd: Double?
    let softLimitUsd: Double?

    enum CodingKeys: String, CodingKey {
        case hardLimitUsd = "hard_limit_usd"
        case softLimitUsd = "soft_limit_usd"
    }
}
