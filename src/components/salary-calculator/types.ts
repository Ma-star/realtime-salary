export interface SalaryData {
  amount: number;
  period: Period;
  currency: string;
  workingHours: number;
  holidayDays: number;
  workStartTime: string;
  workEndTime: string;
  breakPaid: boolean;
  overtimeMultiplier: number;
  bonusPlan: BonusPlan;
  privacyMode: PrivacyMode;
  tone: EncouragementTone;
}

export type Period = 'yearly' | 'monthly' | 'weekly' | 'hourly';
export type BonusType = 'none' | 'fixed' | 'months' | 'percentage' | 'target';
export type PrivacyMode = 'visible' | 'masked' | 'hidden';
export type EncouragementTone = 'gentle' | 'funny' | 'calm' | 'direct';

export interface BonusPlan {
  type: BonusType;
  value: number;
  personalCoefficient?: number;
  companyCoefficient?: number;
  attendanceCoefficient?: number;
}

export interface PersistedWorkSession {
  elapsedMs: number;
  unpaidBreakMs: number;
  paidBreakMs: number;
  isRunning: boolean;
  breakMode: 'none' | 'paid' | 'unpaid';
  overtimeConfirmed: boolean;
  savedAt: number;
}

export const bonusTypeLabels: Record<BonusType, string> = {
  none: '暂不设置',
  fixed: '固定奖金',
  months: '固定月数',
  percentage: '年薪比例',
  target: '目标率 × 绩效系数',
};

export const periodLabels: Record<Period, string> = {
  yearly: '年薪',
  monthly: '月薪',
  weekly: '周薪',
  hourly: '时薪'
};

// 预设的节假日方案
export const holidayPresets = [
  { label: '中国标准（115天）', value: 115 }, // 104天周末 + 11天法定节假日
  { label: '无节假日', value: 0 },
  { label: '自定义', value: 'custom' }
] as const;

// 薪资预设方案
export const salaryPresets = [
  { label: '月薪1万', amount: 10000, period: 'monthly' as Period, description: "" },
  { label: '月薪2万', amount: 20000, period: 'monthly' as Period, description: "" },
  { label: '年薪50万', amount: 500000, period: 'yearly' as Period, description: "" },
  { label: '年薪100万', amount: 1000000, period: 'yearly' as Period ,description: "" },
  { label: '年薪一个亿', amount: 100000000, period: 'yearly' as Period,description: "" },
  { label: '存款一个亿(年化2%)', amount: 2000000, period: 'yearly' as Period, description: '一亿存款年化2%的利息收入' },
  { label: '躺着赚一个亿', amount: 100000000, period: 'yearly' as Period, description: '每年躺着就能赚一个亿，人生赢家！' }
] as const;

// 一年工作日计算：365天 - 节假日天数
export const periodSeconds: Record<Period, (workingHours: number, holidayDays: number) => number> = {
  yearly: (workingHours, holidayDays) => {
    const workingDays = 365 - holidayDays;
    return workingDays * workingHours * 3600;
  },
  monthly: (workingHours, holidayDays) => {
    const workingDays = 30 - Math.round(holidayDays / 12); // 每月平均节假日
    return workingDays * workingHours * 3600;
  },
  weekly: (workingHours, holidayDays) => {
    const workingDays = 7 - Math.round(holidayDays / 52); // 每周平均节假日
    return workingDays * workingHours * 3600;
  },
  hourly: () => 3600 // 1小时
};

export const currencySymbols: Record<string, string> = {
  'CNY': '¥',
  'USD': '$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥'
};

export interface DelightItem {
  emoji: string;
  label: string;
  amount: number;
}

const delightCatalog: Record<string, DelightItem[]> = {
  CNY: [
    { emoji: '☕️', label: '一杯热咖啡', amount: 18 },
    { emoji: '🥤', label: '一杯奶茶', amount: 25 },
    { emoji: '🍜', label: '一顿好好吃的午饭', amount: 45 },
    { emoji: '🚕', label: '一次放心打车', amount: 80 },
    { emoji: '🍲', label: '一顿热气腾腾的火锅', amount: 180 },
    { emoji: '🎧', label: '一份想买很久的小礼物', amount: 500 },
  ],
  USD: [
    { emoji: '☕️', label: 'a coffee', amount: 5 },
    { emoji: '🥗', label: 'a good lunch', amount: 15 },
    { emoji: '🚕', label: 'a comfortable ride home', amount: 30 },
    { emoji: '🎧', label: 'a small treat', amount: 80 },
  ],
};

export function getDelightItems(currency: string): DelightItem[] {
  if (delightCatalog[currency]) return delightCatalog[currency];

  const fallbackRate = currency === 'JPY' ? 20 : 1;
  return delightCatalog.USD.map((item) => ({
    ...item,
    amount: item.amount * fallbackRate,
  }));
}
