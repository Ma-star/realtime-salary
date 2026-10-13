import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SalaryProfile

    init(profile: SalaryProfile) {
        _draft = State(initialValue: profile)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("下班回血器", systemImage: "sparkles")
                            .font(.title2.bold())
                            .foregroundStyle(.indigo)
                        Text("奖金不画饼，工资只加密保存在这台 iPhone。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("收入设置") {
                    HStack {
                        Text("薪资金额")
                        Spacer()
                        TextField("120000", value: $draft.amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("计算周期", selection: $draft.period) {
                        ForEach(SalaryPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    Picker("货币", selection: $draft.currency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text("\(currency.title) (\(currency.symbol))").tag(currency)
                        }
                    }
                }

                Section("工作节奏") {
                    Stepper("每天 \(draft.workingHours, specifier: "%.1f") 小时", value: $draft.workingHours, in: 1...16, step: 0.5)
                    Stepper("每年休息 \(draft.holidayDays) 天", value: $draft.holidayDays, in: 0...364)
                    DatePicker("上班时间", selection: workStartBinding, displayedComponents: .hourAndMinute)
                    DatePicker(
                        "下班时间",
                        selection: workEndBinding,
                        displayedComponents: .hourAndMinute
                    )
                    Toggle("休息时间照常计薪", isOn: $draft.breakPaid)
                    Stepper("加班倍率 \(draft.overtimeMultiplier, specifier: "%.1f")×", value: $draft.overtimeMultiplier, in: 1...5, step: 0.1)
                }

                Section {
                    Picker("奖金规则", selection: $draft.bonusPlan.type) {
                        ForEach(BonusType.allCases) { type in Text(type.title).tag(type) }
                    }
                    if draft.bonusPlan.type != .none {
                        HStack {
                            Text(bonusValueLabel)
                            Spacer()
                            TextField("0", value: $draft.bonusPlan.value, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    if draft.bonusPlan.type == .target {
                        coefficientField("个人系数", value: $draft.bonusPlan.personalCoefficient)
                        coefficientField("公司系数", value: $draft.bonusPlan.companyCoefficient)
                        coefficientField("出勤系数", value: $draft.bonusPlan.attendanceCoefficient)
                    }
                } header: {
                    Text("奖金天气")
                } footer: {
                    Text("系数不知道就留空。未公布时只显示待确认，不会默认按 1 计算。")
                }

                Section("隐私与陪伴") {
                    Picker("默认金额显示", selection: $draft.privacyMode) {
                        ForEach(PrivacyMode.allCases) { mode in Text(mode.title).tag(mode) }
                    }
                    Picker("陪伴语气", selection: $draft.tone) {
                        ForEach(EncouragementTone.allCases) { tone in Text(tone.title).tag(tone) }
                    }
                }

                Section {
                    Button {
                        guard draft.amount > 0 else { return }
                        store.profile = draft
                        dismiss()
                    } label: {
                        Label(store.profile == nil ? "开始回血" : "保存设置", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.amount <= 0)
                } footer: {
                    Text("资料使用 AES-GCM 加密，密钥保存在仅本机可用的钥匙串；我们不会上传、同步或分析你的薪资。")
                }
            }
            .navigationTitle(store.profile == nil ? "先认识一下你" : "调整设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.profile != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
            }
        }
    }

    private var workEndBinding: Binding<Date> {
        Binding(
            get: { draft.workEndDate },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                draft.workEndHour = components.hour ?? 18
                draft.workEndMinute = components.minute ?? 0
            }
        )
    }

    private var workStartBinding: Binding<Date> {
        Binding(
            get: { draft.workStartDate },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                draft.workStartHour = components.hour ?? 9
                draft.workStartMinute = components.minute ?? 0
            }
        )
    }

    private var bonusValueLabel: String {
        switch draft.bonusPlan.type {
        case .fixed: "固定奖金"
        case .months: "奖金月数"
        case .percentage, .target: "目标比例 (%)"
        case .none: "奖金"
        }
    }

    private func coefficientField(_ title: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("待公布", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
