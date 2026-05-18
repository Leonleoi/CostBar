// Utils/Constants.swift
import Foundation

enum AppConstants {
    static let appName = "AIUsageTracker"
    static let defaultRefreshInterval: TimeInterval = 300 // 5 minutes
    static let minRefreshInterval: TimeInterval = 30
    static let maxRefreshInterval: TimeInterval = 3600

    enum DeepSeek {
        static let baseURL = "https://api.deepseek.com"
        static let balanceEndpoint = "/user/balance"
        static let usageEndpoint = "/dashboard/billing/usage"
    }

    enum OpenAI {
        static let baseURL = "https://api.openai.com"
        static let balanceEndpoint = "/dashboard/billing/subscription"
        static let usageEndpoint = "/dashboard/billing/usage"
    }

    enum Anthropic {
        static let baseURL = "https://api.anthropic.com"
        static let usageEndpoint = "/v1/usage"
    }
}
