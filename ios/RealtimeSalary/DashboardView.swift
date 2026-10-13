import LocalAuthentication
import SwiftUI
import UIKit

struct DashboardView: View {
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
    @State private var showsSettlement = false
    @State private var eraseArmed = false
    @State private var tickCount = 0
    @State private var now = Date()

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var result: DailySettlement { EarningsEngine.settle(profile: profile, elapsed: elapsed, unpaidBreak: unpaidBreak, overtimeConfirmed: overtimeConfirmed) }
    private var projection: BonusProjection { EarningsEngine.bonus(for: profile) }
    private var perSecond: Double { EarningsEngine.earnings(for: 1, profile: profile) }
    private var progress: Double { min(1, result.paid / (profile.workingHours * 3_600)) }
    private var delights: [DelightItem] { EarningsEngine.delights(for: profile.currency) }
    private var nextDelight: DelightItem? { delights.first { result.lockedTotal < $0.amount } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                privacyBar
                heroCard
                statusCards
                if result.overtime > 0 && !overtimeConfirmed { overtimePrompt }
                delightCard
                moodCard
                controls
                eraseButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("下班回血器")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("调整设置", systemImage: "slider.horizontal.3") { showsSetup = true }
                    Toggle("深色模式", isOn: $store.usesDarkMode)
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showsSettlement) {
            SettlementView(profile: profile, result: result, initialMood: mood) { selectedMood, releaseChoice in
                store.saveSettlement(result, mood: selectedMood, releaseChoice: releaseChoice)
                resetSession(startRunning: false)
            }
        }
        .onAppear { restoreSession() }
        .onReceive(timer) { date in tick(date) }
        .onDisappear { persistSession() }
        .privacySensitive()
    }

    private var privacyBar: some View {
        HStack {
            Label("设备加密保险箱", systemImage: "lock.shield.fill").font(.caption.bold()).foregroundStyle(.green)
            Spacer()
            Button { togglePrivacy() } label: { Image(systemName: privacyMode == .visible ? "eye.fill" : "eye.slash.fill") }
                .accessibilityLabel("切换金额显示")
            Button("老板来了") { privacyMode = .hidden }
                .font(.caption.bold()).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(12).background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日已锁定劳动价值").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    Text(amount(result.lockedTotal)).font(.system(size: 42, weight: .black, design: .rounded)).minimumScaleFactor(0.58).lineLimit(1)
                    if result.estimatedTotal > result.lockedTotal, privacyMode == .visible {
                        Text("含奖金/加班预计 \(currency(result.estimatedTotal))").font(.caption).foregroundStyle(.white.opacity(0.68))
                    }
                }
                Spacer()
                Label(statusText, systemImage: isRunning ? "circle.fill" : "pause.circle.fill")
                    .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 7).background(.white.opacity(0.16), in: Capsule())
            }
            HStack(spacing: 8) {
                metric(title: "实际工作", value: duration(max(0, elapsed - paidBreak - unpaidBreak)))
                metric(title: "计薪时间", value: duration(result.paid))
                metric(title: "无薪休息", value: duration(unpaidBreak))
            }
            ProgressView(value: progress).tint(.white)
        }
        .foregroundStyle(.white).padding(20)
        .background(LinearGradient(colors: [.indigo, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .indigo.opacity(0.22), radius: 18, y: 10)
    }

    private var statusCards: some View {
        HStack(spacing: 10) {
            statusCard(title: "下班倒计时", value: offWorkCountdown, subtitle: String(format: "%02d:%02d 下班", profile.workEndHour, profile.workEndMinute), icon: "clock.badge.checkmark.fill", color: .indigo)
            statusCard(title: "奖金天气", value: bonusDisplay, subtitle: bonusSubtitle, icon: "cloud.sun.fill", color: .pink)
        }
    }

    private var overtimePrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("检测到 \(friendlyDuration(result.overtime)) 超出计划工时").font(.headline)
            Text("未确认前不计入金额，防止忘记停表被当成加班。").font(.caption).foregroundStyle(.secondary)
            Button("确认为临时加班 · \(profile.overtimeMultiplier, specifier: "%.1f")×") { overtimeConfirmed = true; persistSession() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }

    private var delightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("劳动结晶", systemImage: "sparkles").font(.headline)
            Text("只用已锁定收入解锁，不拿预计奖金画饼").font(.caption).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(delights) { item in
                    let unlocked = result.lockedTotal >= item.amount
                    HStack(spacing: 5) { if unlocked { Image(systemName: "checkmark.circle.fill") }; Text("\(item.emoji) \(item.title)") }
                        .font(.caption.bold()).foregroundStyle(unlocked ? .green : .secondary).padding(.horizontal, 10).padding(.vertical, 7)
                        .background(unlocked ? Color.green.opacity(0.1) : Color(.secondarySystemBackground), in: Capsule())
                }
            }
            if let nextDelight {
                VStack(spacing: 7) {
                    HStack { Text("下一份：\(nextDelight.emoji) \(nextDelight.title)"); Spacer(); Text(timeToUnlock(nextDelight)) }.font(.caption)
                    ProgressView(value: min(1, result.lockedTotal / nextDelight.amount))
                }.padding(12).background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
        }.cardStyle()
    }

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label("情绪补给站", systemImage: "heart.text.square.fill").font(.headline); Spacer(); Text("你现在怎么样？").font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 6) {
                ForEach(Mood.allCases) { item in
                    Button { mood = item } label: { VStack(spacing: 3) { Text(item.emoji).font(.title3); Text(item.title).font(.caption2) }.frame(maxWidth: .infinity).padding(.vertical, 7) }
                        .buttonStyle(.plain).foregroundStyle(mood == item ? .white : .primary).background(mood == item ? Color.indigo : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text(encouragement).font(.subheadline.weight(.medium)).foregroundStyle(.orange).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }.cardStyle()
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { isRunning.toggle(); lastTick = Date(); persistSession(); UIImpactFeedbackGenerator(style: .soft).impactOccurred() } label: { Label(isRunning ? "暂停" : "继续", systemImage: isRunning ? "pause.fill" : "play.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                Button { toggleBreak() } label: { Label(breakMode == .none ? "开始休息" : "结束休息", systemImage: "cup.and.saucer.fill").frame(maxWidth: .infinity) }.buttonStyle(.bordered).disabled(!isRunning)
            }
            HStack(spacing: 10) {
                Button("重置", systemImage: "arrow.counterclockwise") { resetSession(startRunning: true) }.frame(maxWidth: .infinity).buttonStyle(.bordered)
                Button("下班结算", systemImage: "moon.stars.fill") { isRunning = false; persistSession(); showsSettlement = true }.frame(maxWidth: .infinity).buttonStyle(.borderedProminent).tint(.purple)
            }
        }.controlSize(.large)
    }

    private var eraseButton: some View {
        Button(role: .destructive) {
            if eraseArmed { store.eraseAllPrivateData() } else { eraseArmed = true; DispatchQueue.main.asyncAfter(deadline: .now() + 5) { eraseArmed = false } }
        } label: { Label(eraseArmed ? "再次点击确认抹除" : "彻底抹除本机数据", systemImage: "trash") }.font(.caption)
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
        if tickCount % 8 == 0 { persistSession() }
    }

    private func restoreSession() {
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

    private func persistSession() { store.saveActiveSession(WorkSessionState(elapsed: elapsed, paidBreak: paidBreak, unpaidBreak: unpaidBreak, isRunning: isRunning, breakMode: breakMode, overtimeConfirmed: overtimeConfirmed, savedAt: Date())) }
    private func resetSession(startRunning: Bool) { elapsed = 0; paidBreak = 0; unpaidBreak = 0; breakMode = .none; overtimeConfirmed = false; isRunning = startRunning; lastTick = Date(); store.clearActiveSession() }
    private func toggleBreak() { breakMode = breakMode == .none ? (profile.breakPaid ? .paid : .unpaid) : .none; persistSession() }

    private func togglePrivacy() {
        if privacyMode == .visible { privacyMode = .masked; return }
        let context = LAContext(); var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { privacyMode = .visible; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "查看你的薪资金额") { success, _ in if success { DispatchQueue.main.async { privacyMode = .visible } } }
    }

    private var statusText: String { !isRunning ? "已暂停" : breakMode == .paid ? "带薪喘气" : breakMode == .unpaid ? "无薪休息" : "劳动中" }
    private var bonusDisplay: String { profile.bonusPlan.type == .none ? "未设置" : projection.isComplete ? amount(projection.expected) : "待系数公布" }
    private var bonusSubtitle: String { projection.isComplete ? "低 \(amount(projection.low)) · 高 \(amount(projection.high))" : projection.missingFields.joined(separator: "、") }
    private var offWorkCountdown: String { let remaining = profile.workEndDate.timeIntervalSince(now); guard remaining > 0 else { return "下班快乐 🎉" }; let minutes = Int(ceil(remaining / 60)); return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟" }
    private var encouragement: String {
        switch profile.tone {
        case .gentle: mood == .broken ? "不是你不够好，是今天真的很难。" : "工作是手段，生活才是主线。"
        case .funny: mood == .tired ? "带薪喘气不是摸鱼，是人类散热。" : "今日目标：平安发育，拒绝白给。"
        case .calm: mood == .broken ? "降低今天的预期，只处理下一件事。" : "维持节奏，到点收工。"
        case .direct: mood == .legendary ? "今天已经足够好，不要用加班稀释它。" : "做完必要的，然后下班。"
        }
    }

    private func amount(_ value: Double) -> String { switch privacyMode { case .visible: currency(value); case .masked: "\(profile.currency.symbol) ••••"; case .hidden: "价值已安全隐藏" } }
    private func currency(_ value: Double) -> String { value.formatted(.currency(code: profile.currency.rawValue)) }
    private func duration(_ seconds: TimeInterval) -> String { let total = max(0, Int(seconds)); return String(format: "%02d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60) }
    private func friendlyDuration(_ seconds: TimeInterval) -> String { let minutes = Int(seconds / 60); return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟" }
    private func timeToUnlock(_ item: DelightItem) -> String { guard perSecond > 0 else { return "--" }; let seconds = max(0, (item.amount - result.lockedTotal) / perSecond); if seconds < 60 { return "约 \(max(1, Int(ceil(seconds)))) 秒" }; if seconds < 3_600 { return "约 \(Int(ceil(seconds / 60))) 分钟" }; return "约 \(Int(seconds / 3_600)) 小时" }
    private func metric(title: String, value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption2).foregroundStyle(.white.opacity(0.65)); Text(value).font(.caption.bold()).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)) }
    private func statusCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View { VStack(alignment: .leading, spacing: 6) { Label(title, systemImage: icon).font(.caption.bold()).foregroundStyle(color); Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.7); Text(subtitle.isEmpty ? "可在设置中补充" : subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)) }
}

private struct SettlementView: View {
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
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) { HStack { VStack(alignment: .leading) { Text("下班结算协议").font(.caption.bold()).foregroundStyle(.indigo); Text(title).font(.title2.bold()) }; Spacer(); Text("\(step)/5").font(.headline).foregroundStyle(.indigo) }; ProgressView(value: Double(step), total: 5) }.padding()
                ScrollView { VStack(alignment: .leading, spacing: 16) { content }.frame(maxWidth: .infinity, alignment: .leading).padding() }
                if step < 5 { Button("下一步", systemImage: "chevron.right") { step += 1 }.frame(maxWidth: .infinity).buttonStyle(.borderedProminent).controlSize(.large).padding() }
                else if !sealed { Button("确认封账", systemImage: "lock.fill") { onSeal(mood, releaseChoice); sealed = true; UINotificationFeedbackGenerator().notificationOccurred(.success) }.frame(maxWidth: .infinity).buttonStyle(.borderedProminent).controlSize(.large).padding() }
                else { ShareLink(item: redactedReport) { Label("分享脱敏战报", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large).padding() }
            }
            .navigationTitle("下班了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(sealed ? "完成" : "稍后") { dismiss() } } }
        }
    }

    @ViewBuilder private var content: some View {
        if step == 1 { row("班次总跨度", friendly(result.elapsed)); row("实际计薪", friendly(result.paid)); row("无薪休息", friendly(result.unpaidBreak)); row("已锁定基础价值", currency(result.lockedTotal)); Text("以上按当前方案折算，不代表公司工资条。").font(.caption).foregroundStyle(.secondary) }
        else if step == 2 { row("超出计划工时", friendly(result.overtime)); row("加班预计", currency(result.overtimeEstimated)); row("奖金摊算", currency(result.bonusAccrued)); Text("预计收入与已锁定金额分开，不把不确定收入当到账。").font(.caption).foregroundStyle(.secondary) }
        else if step == 3 { Text("收工前，给今天标个温度。这个选择只留在本机。"); moodPicker }
        else if step == 4 { Text("选一件要留在今天的事，不带回生活里。"); ForEach(["把没开完的会留在今天", "把别人的情绪留在今天", "把没做完的事交给明天的我"], id: \.self) { choice in Button(choice) { releaseChoice = choice }.buttonStyle(.bordered).tint(releaseChoice == choice ? .indigo : .secondary) }; TextField("也可以自己写一句（可跳过）", text: $releaseChoice).textFieldStyle(.roundedBorder) }
        else { VStack(spacing: 12) { Image(systemName: sealed ? "checkmark.seal.fill" : "moon.stars.fill").font(.system(size: 54)).foregroundStyle(.indigo); Text(sealed ? "今天已经完整封账" : "准备把今天收好").font(.title.bold()); Text(releaseChoice.isEmpty ? "工作留在今天，生活现在开始。" : releaseChoice).foregroundStyle(.secondary); Text(currency(result.lockedTotal)).font(.largeTitle.bold()).foregroundStyle(.indigo) }.frame(maxWidth: .infinity) }
    }

    private var moodPicker: some View { HStack(spacing: 6) { ForEach(Mood.allCases) { item in Button { mood = item } label: { VStack { Text(item.emoji).font(.title2); Text(item.title).font(.caption2) }.frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.plain).foregroundStyle(mood == item ? .white : .primary).background(mood == item ? Color.indigo : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12)) } } }
    private var title: String { ["", "对账：今天发生了什么", "确认：额外付出单独记", "心情：不评判，只记录", "放下：不带回生活里", "封账：现在可以下班了"][step] }
    private var redactedReport: String { "🌙 今日已封账\n劳动 \(friendly(result.paid))，休息 \(friendly(result.unpaidBreak))\n\(releaseChoice.isEmpty ? "工作留在今天，生活现在开始。" : releaseChoice)\n（金额已默认隐藏）" }
    private func row(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).bold() } }
    private func currency(_ value: Double) -> String { value.formatted(.currency(code: profile.currency.rawValue)) }
    private func friendly(_ seconds: TimeInterval) -> String { let minutes = Int(seconds / 60); return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟" }
}

private extension View { func cardStyle() -> some View { padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous)) } }

private struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { layout(proposal: proposal, subviews: subviews).size }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { let result = layout(proposal: proposal, subviews: subviews); for (index, point) in result.points.enumerated() { subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified) } }
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) { let maxWidth = proposal.width ?? 0; var points: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0; for subview in subviews { let size = subview.sizeThatFits(.unspecified); if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }; points.append(CGPoint(x: x, y: y)); x += size.width + spacing; rowHeight = max(rowHeight, size.height) }; return (CGSize(width: maxWidth, height: y + rowHeight), points) }
}
