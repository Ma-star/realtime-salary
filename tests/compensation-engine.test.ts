import assert from 'node:assert/strict';
import test from 'node:test';
import { projectBonus, settleDay } from '../src/components/salary-calculator/compensation-engine.ts';
import type { SalaryData } from '../src/components/salary-calculator/types.ts';

const baseProfile: SalaryData = {
  amount: 120_000,
  period: 'yearly',
  currency: 'CNY',
  workingHours: 8,
  holidayDays: 115,
  workStartTime: '09:00',
  workEndTime: '18:00',
  breakPaid: false,
  overtimeMultiplier: 1.5,
  privacyMode: 'masked',
  tone: 'gentle',
  bonusPlan: {
    type: 'target',
    value: 10,
    personalCoefficient: 1.1,
    companyCoefficient: 0.8,
    attendanceCoefficient: 1,
  },
};

test('target bonus uses rate and all coefficients', () => {
  const projection = projectBonus(baseProfile);
  assert.equal(projection.isComplete, true);
  assert.equal(Math.round(projection.expected * 100), 1_056_000);
  assert.equal(Math.round(projection.low * 100), 844_800);
  assert.equal(Math.round(projection.high * 100), 1_267_200);
});

test('target bonus stays incomplete when a coefficient is missing', () => {
  const profile = {
    ...baseProfile,
    bonusPlan: { ...baseProfile.bonusPlan, companyCoefficient: undefined },
  };
  const projection = projectBonus(profile);
  assert.equal(projection.isComplete, false);
  assert.equal(projection.expected, 0);
  assert.deepEqual(projection.missingFields, ['公司绩效系数']);
});

test('daily settlement separates locked base, estimated bonus, break and overtime', () => {
  const result = settleDay(baseProfile, 10 * 3_600, 3_600, true);
  assert.equal(result.paidSeconds, 9 * 3_600);
  assert.equal(result.overtimeSeconds, 3_600);
  assert.equal(result.baseAccrued, 480);
  assert.equal(result.overtimeEstimated, 90);
  assert.equal(Math.round(result.bonusAccrued * 100) / 100, 42.24);
  assert.equal(result.lockedTotal, 480);
});
