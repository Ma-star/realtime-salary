import Foundation

enum SalaryPeriod: String, Codable, CaseIterable, Identifiable {
    case yearly, monthly, weekly, hourly
    var id: String { rawValue }
    var title: String { switch self { case .yearly: "年薪"; case .monthly: "月薪"; case .weekly: "周薪"; case .hourly: "时薪" } }
}

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case CNY, USD, EUR, GBP, JPY
    var id: String { rawValue }
    var title: String { switch self { case .CNY: "人民币"; case .USD: "美元"; case .EUR: "欧元"; case .GBP: "英镑"; case .JPY: "日元" } }
    var symbol: String { switch self { case .CNY, .JPY: "¥"; case .USD: "$"; case .EUR: "€"; case .GBP: "£" } }
}

enum BonusType: String, Codable, CaseIterable, Identifiable {
    case none, fixed, months, percentage, target
    var id: String { rawValue }
    var title: String { switch self { case .none: "暂不设置"; case .fixed: "固定金额"; case .months: "月薪倍数"; case .percentage: "年薪比例"; case .target: "目标奖金 × 系数" } }
}

enum PrivacyMode: String, Codable, CaseIterable, Identifiable {
    case visible, masked, hidden
    var id: String { rawValue }
    var title: String { switch self { case .visible: "显示金额"; case .masked: "默认打码"; case .hidden: "完全隐藏" } }
}

enum EncouragementTone: String, Codable, CaseIterable, Identifiable {
    case gentle, funny, calm, direct
    var id: String { rawValue }
    var title: String { switch self { case .gentle: "温柔托住"; case .funny: "打工人玩梗"; case .calm: "冷静克制"; case .direct: "直接清醒" } }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case broken, tired, fine, good, legendary
    var id: String { rawValue }
    var emoji: String { switch self { case .broken: "🫠"; case .tired: "🪫"; case .fine: "😐"; case .good: "😌"; case .legendary: "🔥" } }
    var title: String { switch self { case .broken: "崩了"; case .tired: "好累"; case .fine: "还行"; case .good: "在线"; case .legendary: "超神" } }
}

enum BreakMode: String, Codable { case none, paid, unpaid }

struct BonusPlan: Codable, Equatable {
    var type: BonusType = .none
    var value: Double = 0
    var personalCoefficient: Double?
    var companyCoefficient: Double?
    var attendanceCoefficient: Double?
}

struct SalaryProfile: Codable, Equatable {
    var amount: Double = 120_000
    var period: SalaryPeriod = .yearly
    var currency: CurrencyCode = .CNY
    var workingHours: Double = 8
    var holidayDays: Int = 115
    var workStartHour: Int = 9
    var workStartMinute: Int = 0
    var workEndHour: Int = 18
    var workEndMinute: Int = 0
    var breakPaid = false
    var overtimeMultiplier: Double = 1.5
    var bonusPlan = BonusPlan()
    var privacyMode: PrivacyMode = .masked
    var tone: EncouragementTone = .gentle

    var workStartDate: Date { Calendar.current.date(bySettingHour: workStartHour, minute: workStartMinute, second: 0, of: Date()) ?? Date() }
    var workEndDate: Date { Calendar.current.date(bySettingHour: workEndHour, minute: workEndMinute, second: 0, of: Date()) ?? Date() }

    init() {}

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        amount = try box.decodeIfPresent(Double.self, forKey: .amount) ?? 120_000
        period = try box.decodeIfPresent(SalaryPeriod.self, forKey: .period) ?? .yearly
        currency = try box.decodeIfPresent(CurrencyCode.self, forKey: .currency) ?? .CNY
        workingHours = try box.decodeIfPresent(Double.self, forKey: .workingHours) ?? 8
        holidayDays = try box.decodeIfPresent(Int.self, forKey: .holidayDays) ?? 115
        workStartHour = try box.decodeIfPresent(Int.self, forKey: .workStartHour) ?? 9
        workStartMinute = try box.decodeIfPresent(Int.self, forKey: .workStartMinute) ?? 0
        workEndHour = try box.decodeIfPresent(Int.self, forKey: .workEndHour) ?? 18
        workEndMinute = try box.decodeIfPresent(Int.self, forKey: .workEndMinute) ?? 0
        breakPaid = try box.decodeIfPresent(Bool.self, forKey: .breakPaid) ?? false
        overtimeMultiplier = try box.decodeIfPresent(Double.self, forKey: .overtimeMultiplier) ?? 1.5
        bonusPlan = try box.decodeIfPresent(BonusPlan.self, forKey: .bonusPlan) ?? BonusPlan()
        privacyMode = try box.decodeIfPresent(PrivacyMode.self, forKey: .privacyMode) ?? .masked
        tone = try box.decodeIfPresent(EncouragementTone.self, forKey: .tone) ?? .gentle
    }
}

struct DelightItem: Identifiable, Equatable { let id: String; let emoji: String; let title: String; let amount: Double }

struct WorkSessionState: Codable {
    var elapsed: TimeInterval = 0
    var paidBreak: TimeInterval = 0
    var unpaidBreak: TimeInterval = 0
    var isRunning = true
    var breakMode: BreakMode = .none
    var overtimeConfirmed = false
    var savedAt = Date()
}

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let paidDuration: TimeInterval
    let unpaidBreakDuration: TimeInterval
    let earnings: Double
    let overtimeEstimated: Double
    let bonusAccrued: Double
    let mood: Mood
    let releaseChoice: String

    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval, paidDuration: TimeInterval, unpaidBreakDuration: TimeInterval, earnings: Double, overtimeEstimated: Double, bonusAccrued: Double, mood: Mood, releaseChoice: String) {
        self.id = id; self.date = date; self.duration = duration; self.paidDuration = paidDuration; self.unpaidBreakDuration = unpaidBreakDuration
        self.earnings = earnings; self.overtimeEstimated = overtimeEstimated; self.bonusAccrued = bonusAccrued; self.mood = mood; self.releaseChoice = releaseChoice
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id); date = try box.decode(Date.self, forKey: .date)
        duration = try box.decode(TimeInterval.self, forKey: .duration)
        paidDuration = try box.decodeIfPresent(TimeInterval.self, forKey: .paidDuration) ?? duration
        unpaidBreakDuration = try box.decodeIfPresent(TimeInterval.self, forKey: .unpaidBreakDuration) ?? 0
        earnings = try box.decode(Double.self, forKey: .earnings)
        overtimeEstimated = try box.decodeIfPresent(Double.self, forKey: .overtimeEstimated) ?? 0
        bonusAccrued = try box.decodeIfPresent(Double.self, forKey: .bonusAccrued) ?? 0
        mood = try box.decodeIfPresent(Mood.self, forKey: .mood) ?? .fine
        releaseChoice = try box.decodeIfPresent(String.self, forKey: .releaseChoice) ?? ""
    }
}

struct BonusProjection { let isComplete: Bool; let annualTarget: Double; let low: Double; let expected: Double; let high: Double; let missingFields: [String] }
struct DailySettlement {
    let elapsed: TimeInterval; let paid: TimeInterval; let unpaidBreak: TimeInterval; let overtime: TimeInterval
    let baseAccrued: Double; let overtimeEstimated: Double; let bonusAccrued: Double
    var lockedTotal: Double { baseAccrued }
    var estimatedTotal: Double { baseAccrued + overtimeEstimated + bonusAccrued }
}

enum EarningsEngine {
    static func periodSeconds(for profile: SalaryProfile) -> Double {
        switch profile.period {
        case .yearly: Double(max(1, 365 - profile.holidayDays)) * profile.workingHours * 3_600
        case .monthly: Double(max(1, 30 - Int((Double(profile.holidayDays) / 12).rounded()))) * profile.workingHours * 3_600
        case .weekly: Double(max(1, 7 - Int((Double(profile.holidayDays) / 52).rounded()))) * profile.workingHours * 3_600
        case .hourly: 3_600
        }
    }

    static func earnings(for seconds: TimeInterval, profile: SalaryProfile) -> Double {
        guard profile.amount > 0 else { return 0 }
        return profile.amount / periodSeconds(for: profile) * max(0, seconds)
    }

    static func annualizedIncome(for profile: SalaryProfile) -> Double {
        switch profile.period {
        case .yearly: profile.amount
        case .monthly: profile.amount * 12
        case .weekly: profile.amount * 52
        case .hourly: profile.amount * Double(max(1, 365 - profile.holidayDays)) * profile.workingHours
        }
    }

    static func bonus(for profile: SalaryProfile) -> BonusProjection {
        let annual = annualizedIncome(for: profile); let plan = profile.bonusPlan
        var target = 0.0; var missing: [String] = []
        switch plan.type {
        case .none: return BonusProjection(isComplete: false, annualTarget: 0, low: 0, expected: 0, high: 0, missingFields: [])
        case .fixed: target = plan.value
        case .months: target = annual / 12 * plan.value
        case .percentage: target = annual * plan.value / 100
        case .target:
            if plan.personalCoefficient == nil { missing.append("个人系数") }
            if plan.companyCoefficient == nil { missing.append("公司系数") }
            if plan.attendanceCoefficient == nil { missing.append("出勤系数") }
            if missing.isEmpty { target = annual * plan.value / 100 * (plan.personalCoefficient ?? 0) * (plan.companyCoefficient ?? 0) * (plan.attendanceCoefficient ?? 0) }
        }
        let complete = missing.isEmpty
        return BonusProjection(isComplete: complete, annualTarget: complete ? target : 0, low: complete ? target * 0.8 : 0, expected: complete ? target : 0, high: complete ? target * 1.2 : 0, missingFields: missing)
    }

    static func settle(profile: SalaryProfile, elapsed: TimeInterval, unpaidBreak: TimeInterval, overtimeConfirmed: Bool) -> DailySettlement {
        let normalizedElapsed = max(0, elapsed); let normalizedBreak = min(normalizedElapsed, max(0, unpaidBreak))
        let paid = normalizedElapsed - normalizedBreak; let planned = profile.workingHours * 3_600; let overtime = max(0, paid - planned)
        let base = earnings(for: paid - overtime, profile: profile)
        let overtimePay = overtimeConfirmed ? earnings(for: overtime, profile: profile) * profile.overtimeMultiplier : 0
        let projection = bonus(for: profile)
        let annualPaidSeconds = Double(max(1, 365 - profile.holidayDays)) * profile.workingHours * 3_600
        let bonusAccrued = projection.isComplete ? projection.annualTarget * min(paid, planned) / annualPaidSeconds : 0
        return DailySettlement(elapsed: normalizedElapsed, paid: paid, unpaidBreak: normalizedBreak, overtime: overtime, baseAccrued: base, overtimeEstimated: overtimePay, bonusAccrued: bonusAccrued)
    }

    static func delights(for currency: CurrencyCode) -> [DelightItem] {
        switch currency {
        case .CNY: [.init(id: "coffee", emoji: "☕️", title: "一杯热咖啡", amount: 18), .init(id: "tea", emoji: "🥤", title: "一杯奶茶", amount: 25), .init(id: "lunch", emoji: "🍜", title: "一顿好好吃的午饭", amount: 45), .init(id: "taxi", emoji: "🚕", title: "一次放心打车", amount: 80), .init(id: "hotpot", emoji: "🍲", title: "一顿热气腾腾的火锅", amount: 180), .init(id: "gift", emoji: "🎧", title: "一份心愿小礼物", amount: 500)]
        case .JPY: [.init(id: "coffee", emoji: "☕️", title: "一杯热咖啡", amount: 500), .init(id: "lunch", emoji: "🍜", title: "一顿好好吃的午饭", amount: 1_500), .init(id: "gift", emoji: "🎧", title: "一份心愿小礼物", amount: 8_000)]
        default: [.init(id: "coffee", emoji: "☕️", title: "一杯热咖啡", amount: 5), .init(id: "lunch", emoji: "🥗", title: "一顿好好吃的午饭", amount: 15), .init(id: "taxi", emoji: "🚕", title: "一次轻松回家的车程", amount: 30), .init(id: "gift", emoji: "🎧", title: "一份心愿小礼物", amount: 80)]
        }
    }
}
