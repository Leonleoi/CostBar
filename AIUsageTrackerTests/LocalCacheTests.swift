// AIUsageTrackerTests/LocalCacheTests.swift
import XCTest
@testable import AIUsageTracker

final class LocalCacheTests: XCTestCase {
    let cache = LocalCache()
    let provider = AIProvider.deepseek

    func testSaveAndLoadUsageHistory() throws {
        let records = [
            UsageRecord(provider: .deepseek, promptTokens: 100, completionTokens: 50, cost: 0.015),
            UsageRecord(provider: .deepseek, promptTokens: 200, completionTokens: 100, cost: 0.03)
        ]
        try cache.saveUsageHistory(records, for: provider)
        let loaded = try cache.loadUsageHistory(for: provider)
        XCTAssertEqual(loaded.count, records.count)
        XCTAssertEqual(loaded[0].totalTokens, 150)
        XCTAssertEqual(loaded[1].totalTokens, 300)
    }
}
