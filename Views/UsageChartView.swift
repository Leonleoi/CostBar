// Views/UsageChartView.swift
import SwiftUI
import Charts

struct UsageChartView: View {
    let records: [UsageRecord]
    let providerName: String
    var currencySymbol: String = "$"
    var displayCost: (UsageRecord) -> Double = { $0.cost }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(providerName) — 30-Day Usage")
                .font(.caption)
                .foregroundColor(.secondary)

            if records.isEmpty {
                Text("No usage data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: 80)
            } else {
                Chart {
                    ForEach(groupedByDay(), id: \.date) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Cost", item.cost)
                        )
                        .foregroundStyle(by: .value("Provider", providerName))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: CurrencyFormatStyle(symbol: currencySymbol))
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private func groupedByDay() -> [(date: Date, cost: Double)] {
        let grouped = Dictionary(grouping: records) { record in
            Calendar.current.startOfDay(for: record.timestamp)
        }
        return grouped.map { (date, items) in
            (date: date, cost: items.reduce(0) { $0 + displayCost($1) })
        }.sorted { $0.date < $1.date }
    }
}

struct CurrencyFormatStyle: FormatStyle {
    typealias FormatInput = Double
    typealias FormatOutput = String

    var symbol: String = "$"

    func format(_ value: Double) -> String {
        String(format: "\(symbol)%.2f", value)
    }
}
