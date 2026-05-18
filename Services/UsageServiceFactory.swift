// Services/UsageServiceFactory.swift
import Foundation

enum UsageServiceFactory {
    static func makeService(for config: ProviderConfig) -> UsageServiceProtocol {
        switch config.provider {
        case .deepseek:
            return DeepSeekService(config: config)
        case .openai:
            return OpenAIService(config: config)
        case .anthropic:
            return AnthropicService(config: config)
        }
    }
}
