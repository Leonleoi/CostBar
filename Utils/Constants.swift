// Utils/Constants.swift
import Foundation

enum AppConstants {
    static let appName = "kx"
    static let defaultRefreshInterval: TimeInterval = 300 // 5 minutes
    static let minRefreshInterval: TimeInterval = 30
    static let maxRefreshInterval: TimeInterval = 3600

    enum DeepSeek {
        static let baseURL = "https://api.deepseek.com"
        static let balanceEndpoint = "/user/balance"
        // DeepSeek does not expose a public usage history API
    }

    enum OpenAI {
        static let baseURL = "https://api.openai.com"
        static let balanceEndpoint = "/dashboard/billing/subscription"
        static let usageEndpoint = "/dashboard/billing/usage"
    }

    enum Anthropic {
        static let baseURL = "https://api.anthropic.com"
    }
}
