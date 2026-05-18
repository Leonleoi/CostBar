import SwiftUI

struct FloatingBalanceView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel

    private var balanceText: String {
        guard let record = dashboardVM.balances[.deepseek] else {
            return "—"
        }
        return String(format: "%.2f %@", record.totalBalance, record.currency)
    }

    private var isAvailable: Bool {
        dashboardVM.balances[.deepseek] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isAvailable ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text("DeepSeek")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if dashboardVM.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }

            Text(balanceText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            if let error = dashboardVM.errorMessages[.deepseek], !error.contains("not support") {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
