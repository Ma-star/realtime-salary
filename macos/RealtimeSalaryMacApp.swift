import AppKit
import Combine
import LocalAuthentication
import SwiftUI

@main
struct RealtimeSalaryMacApp: App {
    @StateObject private var store = SalaryStore()

    var body: some Scene {
        WindowGroup("下班回血器") {
            MacRootView()
                .environmentObject(store)
                .preferredColorScheme(store.preferredColorScheme)
                .frame(minWidth: 760, minHeight: 660)
        }
        .defaultSize(width: 940, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private struct MacRootView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSetup = false

    var body: some View {
        Group {
            if let profile = store.profile {
                MacDashboardView(profile: profile, showsSetup: $showsSetup)
            } else {
                MacSetupView(profile: SalaryProfile(), isInitial: true)
            }
        }
        .sheet(isPresented: $showsSetup) {
            if let profile = store.profile { MacSetupView(profile: profile, isInitial: false) }
        }
        .overlay {
            if scenePhase != .active {
                ZStack {
                    Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 44)).foregroundStyle(.indigo)
                        Text("薪资隐私已遮挡").font(.title2.bold())
                    }
                }
            }
        }
    }
}

private struct MacSetupView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SalaryProfile
    let isInitial: Bool

    init(profile: SalaryProfile, isInitial: Bool) {
        _draft = State(initialValue: profile)
        self.isInitial = isInitial
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("下班回血器", systemImage: "bolt.heart.fill").font(.title2.bold()).foregroundStyle(.indigo)
                    Text("奖金不画饼，工资只加密保存在这台 Mac。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if !isInitial { Button("取消") { dismiss() } }
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("基础薪资") {
                        formRow("薪资金额") { TextField("120000", value: $draft.amount, format: .number).frame(width: 180).multilineTextAlignment(.trailing) }
                        formRow("计算周期") { Picker("", selection: $draft.period) { ForEach(SalaryPeriod.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 180) }
                        formRow("货币") { Picker("", selection: $draft.currency) { ForEach(CurrencyCode.allCases) { Text("\($0.title)（\($0.symbol)）").tag($0) } }.labelsHidden().frame(width: 180) }
                    }

                    section("工作节奏") {
                        formRow("每日计薪工时") { Stepper("\(draft.workingHours, specifier: "%.1f") 小时", value: $draft.workingHours, in: 1...16, step: 0.5).frame(width: 180) }
                        formRow("年度非工作日") { Stepper("\(draft.holidayDays) 天", value: $draft.holidayDays, in: 0...364).frame(width: 180) }
                        formRow("上班时间") { DatePicker("", selection: startTime, displayedComponents: .hourAndMinute).labelsHidden().frame(width: 180) }
                        formRow("下班时间") { DatePicker("", selection: endTime, displayedComponents: .hourAndMinute).labelsHidden().frame(width: 180) }
                        formRow("休息口径") { Toggle("休息照常计薪", isOn: $draft.breakPaid).frame(width: 180) }
                        formRow("加班倍率") { Stepper("\(draft.overtimeMultiplier, specifier: "%.1f")×", value: $draft.overtimeMultiplier, in: 1...5, step: 0.1).frame(width: 180) }
                    }

                    section("奖金天气") {
                        formRow("奖金规则") { Picker("", selection: $draft.bonusPlan.type) { ForEach(BonusType.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 180) }
                        if draft.bonusPlan.type != .none {
                            formRow(bonusValueLabel) { TextField("0", value: $draft.bonusPlan.value, format: .number).frame(width: 180).multilineTextAlignment(.trailing) }
                        }
                        if draft.bonusPlan.type == .target {
                            coefficientRow("个人绩效系数", value: $draft.bonusPlan.personalCoefficient)
                            coefficientRow("公司绩效系数", value: $draft.bonusPlan.companyCoefficient)
                            coefficientRow("出勤系数", value: $draft.bonusPlan.attendanceCoefficient)
                            Text("系数不知道就留空；不会偷偷按 1 计算。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    section("隐私与陪伴") {
                        formRow("默认金额显示") { Picker("", selection: $draft.privacyMode) { ForEach(PrivacyMode.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 180) }
                        formRow("陪伴语气") { Picker("", selection: $draft.tone) { ForEach(EncouragementTone.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 180) }
                        Label("AES-GCM 加密文件 · Keychain 本机密钥 · 不联网", systemImage: "lock.shield.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(24)
            }

            Divider()
            HStack {
                Spacer()
                Button(isInitial ? "开始今天的班次" : "保存方案") {
                    guard draft.amount > 0 else { return }
                    store.profile = draft
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(draft.amount <= 0)
            }
            .padding(20)
        }
        .frame(width: isInitial ? 760 : 620, height: isInitial ? 720 : 680)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            VStack(spacing: 10) { content() }
                .padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title); Spacer(); content() }
    }

    private func coefficientRow(_ title: String, value: Binding<Double?>) -> some View {
        formRow(title) { TextField("待公布", value: value, format: .number).frame(width: 180).multilineTextAlignment(.trailing) }
    }

    private var bonusValueLabel: String {
        switch draft.bonusPlan.type { case .fixed: "固定奖金"; case .months: "奖金月数"; case .percentage, .target: "目标比例（%）"; case .none: "奖金" }
    }

    private var startTime: Binding<Date> {
        Binding(get: { draft.workStartDate }, set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); draft.workStartHour = c.hour ?? 9; draft.workStartMinute = c.minute ?? 0 })
    }

    private var endTime: Binding<Date> {
        Binding(get: { draft.workEndDate }, set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); draft.workEndHour = c.hour ?? 18; draft.workEndMinute = c.minute ?? 0 })
    }
}

private struct MacDashboardView: View {
    @EnvironmentObject private var store: SalaryStore
    let profile: SalaryProfile
    @Binding var showsSetup: Bool

    @State private var elapsed: TimeInterval = 0
    @State private var paidBreak: TimeInterval = 0
    @State private var unpaidBreak: TimeInterval = 0
    @State private var lastTick = Date()
    @State private var isRunning = true
    @State private var breakMode: BreakMode = .none
    @State private var overtimeConfirmed = false
    @State private var privacyMode: PrivacyMode = .masked
    @State private var mood: Mood = .fine
    @State private var now = Date()
    @State private var tickCount = 0
    @State private var showsSettlement = false
    @State private var showsEraseAlert = false

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var result: DailySettlement { EarningsEngine.settle(profile: profile, elapsed: elapsed, unpaidBreak: unpaidBreak, overtimeConfirmed: overtimeConfirmed) }
    private var projection: BonusProjection { EarningsEngine.bonus(for: profile) }
    private var delights: [DelightItem] { EarningsEngine.delights(for: profile.currency) }
    private var nextDelight: DelightItem? { delights.first { result.lockedTotal < $0.amount } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                hero
                HStack(alignment: .top, spacing: 14) {
                    leftColumn
                    rightColumn
                }
                controls
            }
            .padding(22)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { restore() }
        .onReceive(timer) { tick($0) }
        .onDisappear { persist() }
        .sheet(isPresented: $showsSettlement) {
            MacSettlementView(profile: profile, result: result, initialMood: mood) { selectedMood, release in
                store.saveSettlement(result, mood: selectedMood, releaseChoice: release)
                reset(startRunning: false)
            }
        }
        .alert("彻底抹除本机数据？", isPresented: $showsEraseAlert) {
            Button("取消", role: .cancel) { }
            Button("抹除", role: .destructive) { store.eraseAllPrivateData() }
        } message: { Text("薪资方案、当前班次和历史结算都会删除，无法恢复。") }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Label("下班回血器", systemImage: "bolt.heart.fill").font(.title2.bold()).foregroundStyle(.indigo)
                Text("今天的努力，正在兑现。").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Label("本机加密", systemImage: "lock.shield.fill").font(.caption.bold()).foregroundStyle(.green)
            Button { togglePrivacy() } label: { Image(systemName: privacyMode == .visible ? "eye.fill" : "eye.slash.fill") }.help("使用 Touch ID 或设备密码查看金额")
            Button("老板来了") { privacyMode = .hidden }
            Menu {
                Button("调整薪资与规则") { showsSetup = true }
                Toggle("深色模式", isOn: $store.usesDarkMode)
                Divider()
                Button("彻底抹除本机数据", role: .destructive) { showsEraseAlert = true }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    private var hero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("今日已锁定劳动价值").foregroundStyle(.white.opacity(0.72))
                Text(amount(result.lockedTotal)).font(.system(size: 44, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                if result.estimatedTotal > result.lockedTotal, privacyMode == .visible {
                    Text("含奖金/加班预计 \(currency(result.estimatedTotal))").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            heroMetric("实际工作", duration(max(0, elapsed - paidBreak - unpaidBreak)))
            heroMetric("计薪时间", duration(result.paid))
            heroMetric("无薪休息", duration(unpaidBreak))
        }
        .foregroundStyle(.white).padding(24)
        .background(LinearGradient(colors: [.indigo, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .indigo.opacity(0.18), radius: 16, y: 8)
    }

    private var leftColumn: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                infoCard("下班倒计时", offWorkCountdown, "\(String(format: "%02d:%02d", profile.workStartHour, profile.workStartMinute)) - \(String(format: "%02d:%02d", profile.workEndHour, profile.workEndMinute))", "clock.badge.checkmark.fill", .indigo)
                infoCard("奖金天气", bonusDisplay, bonusSubtitle, "cloud.sun.fill", .pink)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("劳动结晶").font(.headline); Spacer(); Text("只算已锁定收入").font(.caption).foregroundStyle(.secondary) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 8) {
                    ForEach(delights) { item in
                        let unlocked = result.lockedTotal >= item.amount
                        Text("\(unlocked ? "✓" : "") \(item.emoji) \(item.title)").font(.caption.bold()).foregroundStyle(unlocked ? .green : .secondary).padding(8).frame(maxWidth: .infinity).background(unlocked ? Color.green.opacity(0.1) : Color(nsColor: .controlBackgroundColor), in: Capsule())
                    }
                }
                if let nextDelight {
                    ProgressView(value: min(1, result.lockedTotal / nextDelight.amount)) { Text("下一份：\(nextDelight.emoji) \(nextDelight.title)").font(.caption) }
                }
            }.card()
            if result.overtime > 0 && !overtimeConfirmed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("检测到 \(friendly(result.overtime)) 超出计划工时").bold()
                    Text("未确认前不计入金额，防止忘记停表。 ").font(.caption).foregroundStyle(.secondary)
                    Button("确认为临时加班 · \(profile.overtimeMultiplier, specifier: "%.1f")×") { overtimeConfirmed = true; persist() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rightColumn: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Label("情绪补给站", systemImage: "heart.text.square.fill").font(.headline); Spacer(); Text("你现在怎么样？").font(.caption).foregroundStyle(.secondary) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                    ForEach(Mood.allCases) { item in
                        Button { mood = item } label: { VStack { Text(item.emoji).font(.title2); Text(item.title).font(.caption2) }.frame(maxWidth: .infinity).padding(.vertical, 7) }
                            .buttonStyle(.plain).foregroundStyle(mood == item ? .white : .primary).background(mood == item ? Color.indigo : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Text(encouragement).font(.subheadline.weight(.medium)).foregroundStyle(.orange).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }.card()

            VStack(alignment: .leading, spacing: 10) {
                Text("最近战绩").font(.headline)
                if store.records.isEmpty { Text("封账一次后，努力会留在这里。 ").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80) }
                else {
                    ForEach(store.records.prefix(5)) { record in
                        HStack { Text(record.mood.emoji); VStack(alignment: .leading) { Text(record.date, format: .dateTime.month().day().hour().minute()).font(.caption.bold()); Text(friendly(record.paidDuration)).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(amount(record.earnings)).font(.subheadline.bold()) }
                        if record.id != store.records.prefix(5).last?.id { Divider() }
                    }
                }
            }.card()
        }
        .frame(width: 330)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(isRunning ? "暂停" : "继续", systemImage: isRunning ? "pause.fill" : "play.fill") { isRunning.toggle(); lastTick = Date(); persist() }.buttonStyle(.borderedProminent)
            Button(breakMode == .none ? "开始休息" : "结束休息", systemImage: "cup.and.saucer.fill") { breakMode = breakMode == .none ? (profile.breakPaid ? .paid : .unpaid) : .none; persist() }.disabled(!isRunning)
            Button("重置", systemImage: "arrow.counterclockwise") { reset(startRunning: true) }
            Spacer()
            Text(statusText).font(.caption.bold()).foregroundStyle(.secondary)
            Button("下班结算", systemImage: "moon.stars.fill") { isRunning = false; persist(); showsSettlement = true }.buttonStyle(.borderedProminent).tint(.purple)
        }.controlSize(.large)
    }

    private func tick(_ date: Date) {
        now = date
        guard isRunning else { lastTick = date; return }
        let delta = max(0, date.timeIntervalSince(lastTick)); lastTick = date
        let maximum = (profile.workingHours + 4) * 3_600
        elapsed = min(maximum, elapsed + delta)
        if breakMode == .paid { paidBreak += delta }
        if breakMode == .unpaid { unpaidBreak += delta }
        if elapsed >= maximum { isRunning = false }
        tickCount += 1
        if tickCount % 8 == 0 { persist() }
    }

    private func restore() {
        privacyMode = profile.privacyMode
        guard let saved = store.activeSession else { lastTick = Date(); return }
        let maximum = (profile.workingHours + 4) * 3_600
        let gap = saved.isRunning ? max(0, Date().timeIntervalSince(saved.savedAt)) : 0
        let recovered = min(gap, max(0, maximum - saved.elapsed))
        elapsed = saved.elapsed + recovered
        paidBreak = saved.paidBreak + (saved.breakMode == .paid ? recovered : 0)
        unpaidBreak = saved.unpaidBreak + (saved.breakMode == .unpaid ? recovered : 0)
        isRunning = saved.isRunning && elapsed < maximum
        breakMode = saved.breakMode; overtimeConfirmed = saved.overtimeConfirmed; lastTick = Date()
    }

    private func persist() { store.saveActiveSession(WorkSessionState(elapsed: elapsed, paidBreak: paidBreak, unpaidBreak: unpaidBreak, isRunning: isRunning, breakMode: breakMode, overtimeConfirmed: overtimeConfirmed, savedAt: Date())) }
    private func reset(startRunning: Bool) { elapsed = 0; paidBreak = 0; unpaidBreak = 0; breakMode = .none; overtimeConfirmed = false; isRunning = startRunning; lastTick = Date(); store.clearActiveSession() }

    private func togglePrivacy() {
        if privacyMode == .visible { privacyMode = .masked; return }
        let context = LAContext(); var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { privacyMode = .visible; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "查看你的薪资金额") { success, _ in if success { DispatchQueue.main.async { privacyMode = .visible } } }
    }

    private var bonusDisplay: String { profile.bonusPlan.type == .none ? "未设置" : projection.isComplete ? amount(projection.expected) : "待系数公布" }
    private var bonusSubtitle: String { projection.isComplete ? "低 \(amount(projection.low)) · 高 \(amount(projection.high))" : projection.missingFields.joined(separator: "、") }
    private var offWorkCountdown: String { let remain = profile.workEndDate.timeIntervalSince(now); guard remain > 0 else { return "下班快乐 🎉" }; let mins = Int(ceil(remain / 60)); return mins >= 60 ? "\(mins / 60) 小时 \(mins % 60) 分" : "\(mins) 分钟" }
    private var statusText: String { !isRunning ? "○ 已暂停" : breakMode == .paid ? "☕ 带薪喘气" : breakMode == .unpaid ? "☾ 无薪休息" : "● 劳动中" }
    private var encouragement: String { switch profile.tone { case .gentle: mood == .broken ? "不是你不够好，是今天真的很难。" : "工作是手段，生活才是主线。"; case .funny: "带薪喘气不是摸鱼，是人类散热。"; case .calm: "维持节奏，到点收工。"; case .direct: "做完必要的，然后下班。" } }
    private func amount(_ value: Double) -> String { switch privacyMode { case .visible: currency(value); case .masked: "\(profile.currency.symbol) ••••"; case .hidden: "价值已安全隐藏" } }
    private func currency(_ value: Double) -> String { value.formatted(.currency(code: profile.currency.rawValue)) }
    private func duration(_ seconds: TimeInterval) -> String { let t = max(0, Int(seconds)); return String(format: "%02d:%02d:%02d", t / 3_600, (t % 3_600) / 60, t % 60) }
    private func friendly(_ seconds: TimeInterval) -> String { let m = Int(seconds / 60); return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟" }
    private func heroMetric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.white.opacity(0.65)); Text(value).font(.headline.monospacedDigit()) }.padding(12).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)) }
    private func infoCard(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View { VStack(alignment: .leading, spacing: 6) { Label(title, systemImage: icon).font(.caption.bold()).foregroundStyle(color); Text(value).font(.title3.bold()).lineLimit(1); Text(subtitle.isEmpty ? "可在设置中补充" : subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).card() }
}

private struct MacSettlementView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: SalaryProfile
    let result: DailySettlement
    let onSeal: (Mood, String) -> Void
    @State private var step = 1
    @State private var mood: Mood
    @State private var releaseChoice = ""
    @State private var sealed = false

    init(profile: SalaryProfile, result: DailySettlement, initialMood: Mood, onSeal: @escaping (Mood, String) -> Void) {
        self.profile = profile; self.result = result; self.onSeal = onSeal; _mood = State(initialValue: initialMood)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { VStack(alignment: .leading) { Text("下班结算协议").font(.caption.bold()).foregroundStyle(.indigo); Text(title).font(.title2.bold()) }; Spacer(); Text("\(step)/5").font(.headline).foregroundStyle(.indigo) }.padding(22)
            ProgressView(value: Double(step), total: 5).padding(.horizontal, 22)
            Divider().padding(.top, 16)
            VStack(alignment: .leading, spacing: 16) { content }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(24)
            Divider()
            HStack {
                if !sealed { Button("稍后") { dismiss() } }
                Spacer()
                if step < 5 { Button("下一步") { step += 1 }.buttonStyle(.borderedProminent) }
                else if !sealed { Button("确认封账") { onSeal(mood, releaseChoice); sealed = true }.buttonStyle(.borderedProminent) }
                else {
                    Button("复制脱敏战报") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(redactedReport, forType: .string) }
                    Button("完成") { dismiss() }.buttonStyle(.borderedProminent)
                }
            }.padding(20)
        }.frame(width: 560, height: 480)
    }

    @ViewBuilder private var content: some View {
        if step == 1 { row("班次总跨度", friendly(result.elapsed)); row("实际计薪", friendly(result.paid)); row("无薪休息", friendly(result.unpaidBreak)); row("已锁定基础价值", currency(result.lockedTotal)); Text("按当前薪资方案折算，不代表公司工资条。 ").font(.caption).foregroundStyle(.secondary) }
        else if step == 2 { row("超出计划工时", friendly(result.overtime)); row("加班预计", currency(result.overtimeEstimated)); row("奖金摊算", currency(result.bonusAccrued)); Text("预计收入不冒充已到账。 ").font(.caption).foregroundStyle(.secondary) }
        else if step == 3 { Text("给今天标个温度，不评判，只记录。 "); HStack { ForEach(Mood.allCases) { item in Button { mood = item } label: { VStack { Text(item.emoji).font(.title); Text(item.title).font(.caption) }.padding(8) }.buttonStyle(.bordered).tint(mood == item ? .indigo : .secondary) } } }
        else if step == 4 { Text("选一件要留在今天的事。 "); ForEach(["把没开完的会留在今天", "把别人的情绪留在今天", "把没做完的事交给明天的我"], id: \.self) { choice in Button(choice) { releaseChoice = choice }.buttonStyle(.bordered).tint(releaseChoice == choice ? .indigo : .secondary) }; TextField("也可以自己写一句（可跳过）", text: $releaseChoice) }
        else { VStack(spacing: 14) { Image(systemName: sealed ? "checkmark.seal.fill" : "moon.stars.fill").font(.system(size: 52)).foregroundStyle(.indigo); Text(sealed ? "今天已经完整封账" : "准备把今天收好").font(.title.bold()); Text(releaseChoice.isEmpty ? "工作留在今天，生活现在开始。" : releaseChoice).foregroundStyle(.secondary); Text(currency(result.lockedTotal)).font(.largeTitle.bold()).foregroundStyle(.indigo) }.frame(maxWidth: .infinity) }
    }

    private var title: String { ["", "对账：今天发生了什么", "确认：额外付出单独记", "心情：不评判，只记录", "放下：不带回生活里", "封账：现在可以下班了"][step] }
    private var redactedReport: String { "🌙 今日已封账\n劳动 \(friendly(result.paid))，休息 \(friendly(result.unpaidBreak))\n\(releaseChoice.isEmpty ? "工作留在今天，生活现在开始。" : releaseChoice)\n（金额已默认隐藏）" }
    private func row(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).bold() } }
    private func currency(_ value: Double) -> String { value.formatted(.currency(code: profile.currency.rawValue)) }
    private func friendly(_ seconds: TimeInterval) -> String { let m = Int(seconds / 60); return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟" }
}

private extension View {
    func card() -> some View { padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16)) }
}
