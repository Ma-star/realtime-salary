import { periodSeconds } from './types.ts';
import type { SalaryData } from './types.ts';

export type IncomeStatus = 'estimated' | 'accrued' | 'locked' | 'paid';

export interface BonusProjection {
  isComplete: boolean;
  annualBase: number;
  annualTarget: number;
  low: number;
  expected: number;
  high: number;
  formula: string;
  missingFields: string[];
}

export interface DailySettlement {
  elapsedSeconds: number;
  paidSeconds: number;
  unpaidBreakSeconds: number;
  overtimeSeconds: number;
  baseAccrued: number;
  overtimeEstimated: number;
  bonusAccrued: number;
  lockedTotal: number;
  estimatedTotal: number;
  bonus: BonusProjection;
}

export function annualizedBase(profile: SalaryData): number {
  switch (profile.period) {
    case 'yearly':
      return profile.amount;
    case 'monthly':
      return profile.amount * 12;
    case 'weekly':
      return profile.amount * 52;
    case 'hourly':
      return profile.amount * Math.max(1, 365 - profile.holidayDays) * profile.workingHours;
  }
}

export function earningsForSeconds(profile: SalaryData, seconds: number): number {
  if (!Number.isFinite(seconds) || seconds <= 0 || profile.amount <= 0) return 0;
  return profile.amount * seconds / periodSeconds[profile.period](profile.workingHours, profile.holidayDays);
}

export function projectBonus(profile: SalaryData): BonusProjection {
  const annualBase = annualizedBase(profile);
  const plan = profile.bonusPlan;
  const missingFields: string[] = [];

  if (plan.type === 'none') {
    return {
      isComplete: false,
      annualBase,
      annualTarget: 0,
      low: 0,
      expected: 0,
      high: 0,
      formula: '未设置奖金，不计入任何收入',
      missingFields: [],
    };
  }

  let target = 0;
  let formula = '';

  if (plan.type === 'fixed') {
    target = plan.value;
    formula = `固定奖金 ${plan.value}`;
  } else if (plan.type === 'months') {
    const monthlyBase = annualBase / 12;
    target = monthlyBase * plan.value;
    formula = `月均基础工资 ${monthlyBase.toFixed(2)} × ${plan.value} 个月`;
  } else if (plan.type === 'percentage') {
    target = annualBase * plan.value / 100;
    formula = `年化基础工资 ${annualBase.toFixed(2)} × ${plan.value}%`;
  } else {
    if (plan.personalCoefficient == null) missingFields.push('个人绩效系数');
    if (plan.companyCoefficient == null) missingFields.push('公司绩效系数');
    if (plan.attendanceCoefficient == null) missingFields.push('出勤系数');

    if (missingFields.length === 0) {
      target = annualBase
        * (plan.value / 100)
        * (plan.personalCoefficient ?? 0)
        * (plan.companyCoefficient ?? 0)
        * (plan.attendanceCoefficient ?? 0);
    }
    formula = `年化基础工资 × ${plan.value}% × 个人系数 × 公司系数 × 出勤系数`;
  }

  const isComplete = missingFields.length === 0 && target >= 0;
  return {
    isComplete,
    annualBase,
    annualTarget: isComplete ? target : 0,
    low: isComplete ? target * 0.8 : 0,
    expected: isComplete ? target : 0,
    high: isComplete ? target * 1.2 : 0,
    formula,
    missingFields,
  };
}

export function settleDay(
  profile: SalaryData,
  elapsedSeconds: number,
  unpaidBreakSeconds: number,
  overtimeConfirmed: boolean,
): DailySettlement {
  const normalizedElapsed = Math.max(0, elapsedSeconds);
  const normalizedBreak = Math.min(normalizedElapsed, Math.max(0, unpaidBreakSeconds));
  const paidSeconds = normalizedElapsed - normalizedBreak;
  const plannedSeconds = profile.workingHours * 3_600;
  const overtimeSeconds = Math.max(0, paidSeconds - plannedSeconds);
  const regularSeconds = Math.max(0, paidSeconds - overtimeSeconds);
  const baseAccrued = earningsForSeconds(profile, regularSeconds);
  const overtimeBase = earningsForSeconds(profile, overtimeSeconds);
  const overtimeEstimated = overtimeConfirmed ? overtimeBase * profile.overtimeMultiplier : 0;
  const bonus = projectBonus(profile);
  const annualPaidSeconds = periodSeconds.yearly(profile.workingHours, profile.holidayDays);
  const bonusAccrued = bonus.isComplete
    ? bonus.annualTarget * Math.min(paidSeconds, plannedSeconds) / annualPaidSeconds
    : 0;

  return {
    elapsedSeconds: normalizedElapsed,
    paidSeconds,
    unpaidBreakSeconds: normalizedBreak,
    overtimeSeconds,
    baseAccrued,
    overtimeEstimated,
    bonusAccrued,
    lockedTotal: baseAccrued,
    estimatedTotal: baseAccrued + overtimeEstimated + bonusAccrued,
    bonus,
  };
}
