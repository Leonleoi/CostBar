// Services/RefreshScheduler.swift
import Foundation
import Combine

final class RefreshScheduler: ObservableObject {
    @Published var isRefreshing = false
    @Published var lastRefreshDate: Date?
    @Published var errorMessage: String?

    private var timer: Timer?
    private var interval: TimeInterval

    init(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        self.interval = interval
    }

    func startAutoRefresh(interval: TimeInterval? = nil) {
        stopAutoRefresh()
        if let newInterval = interval { self.interval = newInterval }
        timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        isRefreshing = false
        lastRefreshDate = Date()

        // The actual refresh logic is in DashboardViewModel
        // This class only manages the timer
    }

    func updateInterval(_ newInterval: TimeInterval) {
        interval = max(AppConstants.minRefreshInterval, min(AppConstants.maxRefreshInterval, newInterval))
        if timer != nil { startAutoRefresh(interval: interval) }
    }

    deinit {
        stopAutoRefresh()
    }
}
