import LocalAuthentication
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: SalaryStore
    let profile: SalaryProfile
    @State private var unlocked = false

    private var totalEarnings: Double { store.records.reduce(0) { $0 + $1.earnings } }
    private var totalDuration: TimeInterval { store.records.reduce(0) { $0 + $1.duration } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    summary(title: "累计回血", value: currency(totalEarnings), icon: "banknote.fill", color: .green)
                    summary(title: "专注时间", value: duration(totalDuration), icon: "timer", color: .indigo)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("最近战绩") {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "还没有记录",
                        systemImage: "chart.bar.xaxis",
                        description: Text("结束一次计时后，努力会留在这里。")
                    )
                } else {
                    ForEach(store.records) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.date, format: .dateTime.month().day().hour().minute())
                                    .font(.subheadline.bold())
                                Text(duration(record.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currency(record.earnings))
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            Section("你的时间价值") {
                LabeledContent("每小时", value: currency(EarningsEngine.earnings(for: 3_600, profile: profile)))
                LabeledContent("每个工作日", value: currency(EarningsEngine.earnings(for: profile.workingHours * 3_600, profile: profile)))
                LabeledContent("年化收入", value: currency(EarningsEngine.annualizedIncome(for: profile)))
            }
        }
        .navigationTitle("我的战绩")
        .privacySensitive()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { authenticate() } label: { Image(systemName: canShowAmounts ? "eye.fill" : "eye.slash.fill") }
                    .accessibilityLabel("解锁战绩金额")
            }
        }
    }

    private func summary(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func currency(_ value: Double) -> String {
        guard canShowAmounts else { return "\(profile.currency.symbol) ••••" }
        return value.formatted(.currency(code: profile.currency.rawValue))
    }

    private var canShowAmounts: Bool { profile.privacyMode == .visible || unlocked }

    private func authenticate() {
        if unlocked { unlocked = false; return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "查看你的薪资战绩") { success, _ in
            if success { DispatchQueue.main.async { unlocked = true } }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 60 { return "\(totalMinutes) 分钟" }
        return "\(totalMinutes / 60) 小时 \(totalMinutes % 60) 分"
    }
}
