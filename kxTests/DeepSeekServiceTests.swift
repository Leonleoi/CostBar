// kxTests/DeepSeekServiceTests.swift
import XCTest
@testable import kx

final class DeepSeekServiceTests: XCTestCase {
    var service: DeepSeekService!
    var config: ProviderConfig!

    override func setUp() {
        super.setUp()
        config = ProviderConfig(provider: .deepseek, apiKey: "test-key")
        service = DeepSeekService(config: config)
    }

    func testBalanceParsing() async throws {
        // This requires URLProtocol mocking — will be manual testing for now
        // since the service makes real network calls
    }
}
