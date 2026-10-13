import { useEffect, useRef, useState } from 'react';
import { ArrowLeftIcon } from '@radix-ui/react-icons';
import {
  BadgePercent,
  Check,
  ChevronRight,
  Clock3,
  Coffee,
  Copy,
  Eye,
  EyeOff,
  HeartHandshake,
  LockKeyhole,
  MoonStar,
  Pause,
  Play,
  RotateCcw,
  ShieldAlert,
  ShieldCheck,
  Trash2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Input } from '@/components/ui/input';
import { SalaryData, PersistedWorkSession, PrivacyMode, getDelightItems } from './types';
import { projectBonus, settleDay } from './compensation-engine';
import { deletePrivateRecord, readPrivateRecord, writePrivateRecord } from '@/lib/private-vault';
import { formatCurrency } from './utils';

interface EarningsDisplayProps {
  salaryData: SalaryData;
  onReset: () => void;
  onEraseAll: () => void;
}

type BreakMode = 'none' | 'paid' | 'unpaid';
type Mood = 'broken' | 'tired' | 'fine' | 'good' | 'legendary';

interface SettlementRecord {
  id: string;
  sealedAt: string;
  elapsedSeconds: number;
  paidSeconds: number;
  unpaidBreakSeconds: number;
  baseAccrued: number;
  overtimeEstimated: number;
  bonusAccrued: number;
  mood: Mood;
  releaseChoice: string;
}

const SESSION_RECORD_ID = 'active-work-session';
const SETTLEMENTS_RECORD_ID = 'daily-settlements';
const moods: Array<{ value: Mood; emoji: string; label: string }> = [
  { value: 'broken', emoji: '🫠', label: '崩了' },
  { value: 'tired', emoji: '🪫', label: '好累' },
  { value: 'fine', emoji: '😐', label: '还行' },
  { value: 'good', emoji: '😌', label: '在线' },
  { value: 'legendary', emoji: '🔥', label: '超神' },
];

export function EarningsDisplay({ salaryData, onReset, onEraseAll }: EarningsDisplayProps) {
  const [elapsedMs, setElapsedMs] = useState(0);
  const [paidBreakMs, setPaidBreakMs] = useState(0);
  const [unpaidBreakMs, setUnpaidBreakMs] = useState(0);
  const [isRunning, setIsRunning] = useState(true);
  const [breakMode, setBreakMode] = useState<BreakMode>('none');
  const [overtimeConfirmed, setOvertimeConfirmed] = useState(false);
  const [privacyMode, setPrivacyMode] = useState<PrivacyMode>(salaryData.privacyMode);
  const [mood, setMood] = useState<Mood>('fine');
  const [encouragementIndex, setEncouragementIndex] = useState(0);
  const [settlementStep, setSettlementStep] = useState(0);
  const [releaseChoice, setReleaseChoice] = useState('');
  const [sealed, setSealed] = useState(false);
  const [copied, setCopied] = useState(false);
  const [eraseArmed, setEraseArmed] = useState(false);
  const [hydrated, setHydrated] = useState(false);
  const lastTick = useRef(Date.now());
  const sessionSnapshot = useRef<PersistedWorkSession | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function restoreSession() {
      const saved = await readPrivateRecord<PersistedWorkSession>(SESSION_RECORD_ID);
      if (cancelled) return;
      if (saved) {
        const maximumMs = (salaryData.workingHours + 4) * 3_600_000;
        const gap = saved.isRunning ? Math.max(0, Date.now() - saved.savedAt) : 0;
        const recoverableGap = Math.min(gap, Math.max(0, maximumMs - saved.elapsedMs));
        setElapsedMs(saved.elapsedMs + recoverableGap);
        setPaidBreakMs(saved.paidBreakMs + (saved.breakMode === 'paid' ? recoverableGap : 0));
        setUnpaidBreakMs(saved.unpaidBreakMs + (saved.breakMode === 'unpaid' ? recoverableGap : 0));
        setIsRunning(saved.isRunning && saved.elapsedMs + recoverableGap < maximumMs);
        setBreakMode(saved.breakMode);
        setOvertimeConfirmed(saved.overtimeConfirmed);
      }
      lastTick.current = Date.now();
      setHydrated(true);
    }
    void restoreSession();
    return () => { cancelled = true; };
  }, [salaryData.workingHours]);

  useEffect(() => {
    if (!hydrated) return;
    lastTick.current = Date.now();
    const timer = window.setInterval(() => {
      const now = Date.now();
      const delta = now - lastTick.current;
      lastTick.current = now;
      if (!isRunning || sealed) return;
      const maximumMs = (salaryData.workingHours + 4) * 3_600_000;
      setElapsedMs((value) => {
        const next = Math.min(maximumMs, value + delta);
        if (next >= maximumMs) setIsRunning(false);
        return next;
      });
      if (breakMode === 'paid') setPaidBreakMs((value) => value + delta);
      if (breakMode === 'unpaid') setUnpaidBreakMs((value) => value + delta);
    }, 250);
    return () => window.clearInterval(timer);
  }, [breakMode, hydrated, isRunning, salaryData.workingHours, sealed]);

  sessionSnapshot.current = {
    elapsedMs,
    unpaidBreakMs,
    paidBreakMs,
    isRunning,
    breakMode,
    overtimeConfirmed,
    savedAt: Date.now(),
  };

  useEffect(() => {
    if (!hydrated || sealed) return;
    const persist = () => {
      if (sessionSnapshot.current) void writePrivateRecord(SESSION_RECORD_ID, sessionSnapshot.current);
    };
    const timer = window.setInterval(persist, 2_000);
    window.addEventListener('pagehide', persist);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener('pagehide', persist);
      persist();
    };
  }, [hydrated, sealed]);

  const result = settleDay(salaryData, elapsedMs / 1_000, unpaidBreakMs / 1_000, overtimeConfirmed);
  const bonus = projectBonus(salaryData);
  const lockedAmount = result.lockedTotal;
  const estimatedAmount = result.estimatedTotal;
  const delightItems = getDelightItems(salaryData.currency);
  const unlockedItems = delightItems.filter((item) => lockedAmount >= item.amount);
  const nextItem = delightItems.find((item) => lockedAmount < item.amount);
  const nextProgress = nextItem ? Math.min(100, lockedAmount / nextItem.amount * 100) : 100;
  const perSecond = salaryData.amount / Math.max(1, getPeriodSeconds(salaryData));
  const secondsToNext = nextItem ? Math.max(0, (nextItem.amount - lockedAmount) / perSecond) : 0;
  const overtimeNeedsConfirmation = result.overtimeSeconds > 0 && !overtimeConfirmed;

  function amount(value: number) {
    if (privacyMode === 'hidden') return '价值已安全隐藏';
    if (privacyMode === 'masked') return `${currencySymbol(salaryData.currency)} ••••`;
    return formatCurrency(value, salaryData.currency);
  }

  return (
    <div className="space-y-5 animate-in fade-in duration-500">
      <div className="flex items-center justify-between rounded-xl border border-emerald-500/20 bg-emerald-500/5 px-3 py-2 text-xs">
        <span className="flex items-center gap-1.5 text-emerald-700 dark:text-emerald-300"><ShieldCheck className="h-4 w-4" />隐私保险箱已开启</span>
        <div className="flex items-center gap-1">
          <button className="rounded-lg px-2 py-1 hover:bg-emerald-500/10" onClick={cyclePrivacyMode} aria-label="切换金额显示">
            {privacyMode === 'visible' ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
          </button>
          <Button variant="ghost" size="sm" className="h-7 px-2 text-xs" onClick={() => setPrivacyMode('hidden')}><ShieldAlert className="mr-1 h-3.5 w-3.5" />老板来了</Button>
        </div>
      </div>

      <div className="rounded-2xl bg-gradient-to-br from-primary via-blue-600 to-violet-600 p-6 text-white shadow-lg shadow-primary/20">
        <div className="mb-5 flex items-start justify-between gap-3">
          <div>
            <p className="text-sm text-white/75">今日已锁定劳动价值</p>
            <p className="mt-1 text-4xl font-black tracking-tight tabular-nums sm:text-5xl">{amount(lockedAmount)}</p>
            {privacyMode === 'visible' && estimatedAmount > lockedAmount && <p className="mt-1 text-xs text-white/65">含奖金/加班预计 {formatCurrency(estimatedAmount, salaryData.currency)}</p>}
          </div>
          <span className="rounded-full bg-white/15 px-3 py-1.5 text-xs font-medium">
            {!isRunning ? '○ 已暂停' : breakMode === 'none' ? '● 劳动中' : breakMode === 'paid' ? '☕ 带薪喘气' : '☾ 无薪休息'}
          </span>
        </div>
        <div className="grid grid-cols-3 gap-2">
          <HeroMetric label="实际工作" value={formatTime(Math.max(0, elapsedMs - paidBreakMs - unpaidBreakMs))} />
          <HeroMetric label="计薪时间" value={formatTime(result.paidSeconds * 1_000)} />
          <HeroMetric label="不计薪休息" value={formatTime(unpaidBreakMs)} />
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <InfoCard icon={<Clock3 className="h-4 w-4 text-primary" />} title="下班倒计时" value={getOffWorkMessage(salaryData.workEndTime)} hint={`班次 ${salaryData.workStartTime} - ${salaryData.workEndTime}`} />
        <InfoCard icon={<BadgePercent className="h-4 w-4 text-fuchsia-500" />} title="奖金天气" value={bonus.isComplete ? amount(bonus.expected) : salaryData.bonusPlan.type === 'none' ? '未设置' : '待系数公布'} hint={bonus.isComplete ? `低 ${amount(bonus.low)} · 高 ${amount(bonus.high)}` : bonus.missingFields.join('、') || '可在设置中添加'} />
      </div>

      <div className="space-y-2">
        <div className="flex justify-between text-sm"><span>{breakMode === 'none' ? '今天的份额正在清楚积累' : breakMode === 'paid' ? '喘口气也是正当需求' : '休息不计薪，但照样有价值'}</span><span className="tabular-nums">{formatTime(elapsedMs)}</span></div>
        <Progress value={Math.min(100, result.paidSeconds / (salaryData.workingHours * 3_600) * 100)} className="h-2.5" />
      </div>

      {overtimeNeedsConfirmation && (
        <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4">
          <p className="font-semibold">检测到 {formatDuration(result.overtimeSeconds)} 超出计划工时</p>
          <p className="mt-1 text-xs text-muted-foreground">未确认前不计入金额，防止把忘记停表算成加班。</p>
          <Button size="sm" className="mt-3" onClick={() => setOvertimeConfirmed(true)}>确认为临时加班 · {salaryData.overtimeMultiplier}x</Button>
        </div>
      )}

      <div className="rounded-2xl border p-4">
        <div className="mb-4"><h3 className="font-semibold">劳动结晶</h3><p className="text-xs text-muted-foreground">只用已锁定基础收入解锁，不拿预计奖金画饼</p></div>
        <div className="flex flex-wrap gap-2">
          {delightItems.map((item) => {
            const unlocked = lockedAmount >= item.amount;
            return <span key={item.label} className={`inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium ${unlocked ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-secondary text-muted-foreground'}`}>{unlocked && <Check className="h-3 w-3" />}{item.emoji} {item.label}</span>;
          })}
        </div>
        {nextItem && <div className="mt-4 rounded-xl bg-primary/5 p-3"><div className="mb-2 flex justify-between text-xs"><span>下一份：{nextItem.emoji} {nextItem.label}</span><span>约 {formatFriendlyDuration(secondsToNext)}</span></div><Progress value={nextProgress} className="h-2" /></div>}
        {unlockedItems.length === delightItems.length && <p className="mt-3 text-sm font-medium text-emerald-700">今天的小确幸已全部解锁，下班后记得兑现给自己。</p>}
      </div>

      <div className="rounded-2xl border p-4">
        <div className="mb-3 flex items-center gap-2"><HeartHandshake className="h-5 w-5 text-amber-500" /><h3 className="font-semibold">情绪补给站</h3><span className="ml-auto text-xs text-muted-foreground">你现在怎么样？</span></div>
        <div className="grid grid-cols-5 gap-1.5">
          {moods.map((item) => <button key={item.value} onClick={() => { setMood(item.value); setEncouragementIndex(0); }} className={`rounded-xl px-1 py-2 text-center transition ${mood === item.value ? 'bg-primary text-primary-foreground' : 'bg-secondary hover:bg-secondary/70'}`}><span className="block text-lg">{item.emoji}</span><span className="text-[11px]">{item.label}</span></button>)}
        </div>
        <div className="mt-3 rounded-xl bg-amber-500/10 p-3 text-sm font-medium"><p>{encouragement(salaryData.tone, mood, encouragementIndex)}</p><button className="mt-2 text-xs underline underline-offset-4" onClick={() => setEncouragementIndex((value) => value + 1)}>再哄我一句</button></div>
      </div>

      {settlementStep > 0 && <SettlementFlow
        step={settlementStep}
        setStep={setSettlementStep}
        result={result}
        mood={mood}
        setMood={setMood}
        releaseChoice={releaseChoice}
        setReleaseChoice={setReleaseChoice}
        sealed={sealed}
        copied={copied}
        onSeal={() => void sealSettlement()}
        onCopy={() => void copyRedactedReport()}
        onNewSession={() => resetSession()}
        onCancel={() => { setSettlementStep(0); setIsRunning(true); }}
        amount={amount}
      />}

      {settlementStep === 0 && (
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <Button onClick={() => setIsRunning((value) => !value)}>{isRunning ? <Pause className="mr-2 h-4 w-4" /> : <Play className="mr-2 h-4 w-4" />}{isRunning ? '暂停' : '继续'}</Button>
          <Button variant={breakMode === 'none' ? 'outline' : 'default'} disabled={!isRunning} onClick={toggleBreak}><Coffee className="mr-2 h-4 w-4" />{breakMode === 'none' ? '开始休息' : '结束休息'}</Button>
          <Button variant="outline" onClick={resetSession}><RotateCcw className="mr-2 h-4 w-4" />重置</Button>
          <Button variant="outline" className="border-primary/30 text-primary" onClick={() => { setIsRunning(false); setSettlementStep(1); }}><MoonStar className="mr-2 h-4 w-4" />下班结算</Button>
        </div>
      )}

      <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-4 text-xs text-muted-foreground">
        <button onClick={onReset} className="inline-flex items-center gap-1 hover:text-foreground"><ArrowLeftIcon />调整薪资与规则</button>
        <button
          onClick={() => {
            if (eraseArmed) onEraseAll();
            else {
              setEraseArmed(true);
              window.setTimeout(() => setEraseArmed(false), 5_000);
            }
          }}
          className="inline-flex items-center gap-1 hover:text-destructive"
        >
          <Trash2 className="h-3.5 w-3.5" />{eraseArmed ? '再次点击确认抹除' : '彻底抹除本机数据'}
        </button>
      </div>
    </div>
  );

  function cyclePrivacyMode() {
    setPrivacyMode((mode) => mode === 'visible' ? 'masked' : mode === 'masked' ? 'hidden' : 'visible');
  }

  function toggleBreak() {
    setBreakMode((mode) => mode === 'none' ? (salaryData.breakPaid ? 'paid' : 'unpaid') : 'none');
  }

  function resetSession() {
    setElapsedMs(0); setPaidBreakMs(0); setUnpaidBreakMs(0); setBreakMode('none'); setOvertimeConfirmed(false); setSealed(false); setSettlementStep(0); setIsRunning(true);
    void deletePrivateRecord(SESSION_RECORD_ID);
  }

  async function sealSettlement() {
    const existing = await readPrivateRecord<SettlementRecord[]>(SETTLEMENTS_RECORD_ID) ?? [];
    const record: SettlementRecord = {
      id: crypto.randomUUID(), sealedAt: new Date().toISOString(), elapsedSeconds: result.elapsedSeconds,
      paidSeconds: result.paidSeconds, unpaidBreakSeconds: result.unpaidBreakSeconds,
      baseAccrued: result.baseAccrued, overtimeEstimated: result.overtimeEstimated,
      bonusAccrued: result.bonusAccrued, mood, releaseChoice,
    };
    await writePrivateRecord(SETTLEMENTS_RECORD_ID, [record, ...existing].slice(0, 90));
    await deletePrivateRecord(SESSION_RECORD_ID);
    setSealed(true);
    setSettlementStep(5);
  }

  async function copyRedactedReport() {
    const text = `🌙 今日已封账\n劳动 ${formatDuration(result.paidSeconds)}，休息 ${formatDuration(result.unpaidBreakSeconds)}\n${releaseChoice || '工作留在今天，生活现在开始。'}\n（金额已默认隐藏）`;
    await navigator.clipboard.writeText(text);
    setCopied(true);
  }
}

function SettlementFlow({ step, setStep, result, mood, setMood, releaseChoice, setReleaseChoice, sealed, copied, onSeal, onCopy, onNewSession, onCancel, amount }: {
  step: number; setStep: (value: number) => void; result: ReturnType<typeof settleDay>; mood: Mood; setMood: (value: Mood) => void; releaseChoice: string; setReleaseChoice: (value: string) => void; sealed: boolean; copied: boolean; onSeal: () => void; onCopy: () => void; onNewSession: () => void; onCancel: () => void; amount: (value: number) => string;
}) {
  return <div className="overflow-hidden rounded-2xl border-2 border-primary/20 bg-gradient-to-b from-primary/10 to-background">
    <div className="border-b border-primary/10 p-4"><div className="flex items-center justify-between"><div><p className="text-xs font-bold tracking-[0.18em] text-primary">下班结算协议</p><h3 className="mt-1 text-xl font-black">{settlementTitle(step)}</h3></div><span className="text-sm font-bold text-primary">{step}/5</span></div><Progress value={step * 20} className="mt-3 h-1.5" /></div>
    <div className="space-y-4 p-5">
      {step === 1 && <><SettlementRow label="班次总跨度" value={formatDuration(result.elapsedSeconds)} /><SettlementRow label="实际计薪" value={formatDuration(result.paidSeconds)} /><SettlementRow label="不计薪休息" value={formatDuration(result.unpaidBreakSeconds)} /><SettlementRow label="已锁定基础价值" value={amount(result.lockedTotal)} /><p className="rounded-xl bg-secondary p-3 text-xs text-muted-foreground">口径：按当前薪资方案和实际计薪时间折算，不代表公司工资条。</p></>}
      {step === 2 && <><p className="text-sm">超出计划工时：<strong>{formatDuration(result.overtimeSeconds)}</strong></p><SettlementRow label="当前加班预计" value={amount(result.overtimeEstimated)} /><p className="text-xs text-muted-foreground">加班只记录你明确确认的时间，不会因忘记停表自动生效。</p></>}
      {step === 3 && <><p className="text-sm font-medium">收工前，给今天标个温度。这个选择只留在本机。</p><div className="grid grid-cols-5 gap-1.5">{moods.map((item) => <button key={item.value} onClick={() => setMood(item.value)} className={`rounded-xl p-2 text-center ${mood === item.value ? 'bg-primary text-primary-foreground' : 'bg-secondary'}`}><span className="block text-xl">{item.emoji}</span><span className="text-[11px]">{item.label}</span></button>)}</div></>}
      {step === 4 && <><p className="text-sm font-medium">选一件要留在今天的事，不带回生活里。</p><div className="grid gap-2">{['把没开完的会留在今天','把别人的情绪留在今天','把没做完的事交给明天的我'].map((choice) => <button key={choice} onClick={() => setReleaseChoice(choice)} className={`rounded-xl border p-3 text-left text-sm ${releaseChoice === choice ? 'border-primary bg-primary/10 text-primary' : ''}`}>{choice}</button>)}</div><Input value={releaseChoice} onChange={(event) => setReleaseChoice(event.target.value)} placeholder="也可以自己写一句（可跳过）" /></>}
      {step === 5 && <div className="text-center"><div className="mx-auto mb-3 flex h-14 w-14 items-center justify-center rounded-full bg-primary text-primary-foreground"><MoonStar className="h-7 w-7" /></div><h3 className="text-2xl font-black">{sealed ? '今天已经完整封账' : '准备把今天收好'}</h3><p className="mt-2 text-sm text-muted-foreground">{releaseChoice || '工作留在今天，生活现在开始。'}</p>{sealed && <p className="mt-4 text-3xl font-black text-primary">{amount(result.lockedTotal)}</p>}</div>}
      <div className="flex gap-2 pt-2">{step < 5 ? <><Button variant="outline" className="flex-1" onClick={onCancel}>暂不结算</Button><Button className="flex-1" onClick={() => setStep(step + 1)}>下一步<ChevronRight className="ml-1 h-4 w-4" /></Button></> : !sealed ? <Button className="w-full" onClick={onSeal}><LockKeyhole className="mr-2 h-4 w-4" />确认封账</Button> : <><Button variant="outline" className="flex-1" onClick={onCopy}>{copied ? <Check className="mr-2 h-4 w-4" /> : <Copy className="mr-2 h-4 w-4" />}{copied ? '已复制' : '脱敏战报'}</Button><Button className="flex-1" onClick={onNewSession}><Play className="mr-2 h-4 w-4" />开启新班次</Button></>}</div>
    </div>
  </div>;
}

function HeroMetric({ label, value }: { label: string; value: string }) { return <div className="rounded-xl bg-white/10 p-3"><span className="text-[11px] text-white/65">{label}</span><p className="truncate text-sm font-semibold tabular-nums">{value}</p></div>; }
function InfoCard({ icon, title, value, hint }: { icon: React.ReactNode; title: string; value: string; hint: string }) { return <div className="rounded-2xl border bg-secondary/35 p-4"><div className="mb-2 flex items-center gap-2 text-sm font-medium">{icon}{title}</div><p className="text-xl font-bold">{value}</p><p className="mt-1 text-xs text-muted-foreground">{hint}</p></div>; }
function SettlementRow({ label, value }: { label: string; value: string }) { return <div className="flex justify-between gap-4 text-sm"><span className="text-muted-foreground">{label}</span><span className="font-medium tabular-nums">{value}</span></div>; }
function settlementTitle(step: number) { return ['','对账：今天发生了什么','加班：额外付出要单独记','心情：不评判，只记录','放下：不带回生活里','封账：现在可以下班了'][step]; }
function formatTime(ms: number) { const total = Math.max(0, Math.floor(ms / 1_000)); return `${String(Math.floor(total / 3_600)).padStart(2,'0')}:${String(Math.floor(total % 3_600 / 60)).padStart(2,'0')}:${String(total % 60).padStart(2,'0')}`; }
function formatDuration(seconds: number) { const minutes = Math.floor(seconds / 60); return minutes >= 60 ? `${Math.floor(minutes / 60)} 小时 ${minutes % 60} 分` : `${minutes} 分钟`; }
function formatFriendlyDuration(seconds: number) { if (!Number.isFinite(seconds)) return '--'; if (seconds < 60) return `${Math.max(1, Math.ceil(seconds))} 秒`; if (seconds < 3_600) return `${Math.ceil(seconds / 60)} 分钟`; return `${Math.floor(seconds / 3_600)} 小时 ${Math.ceil(seconds % 3_600 / 60)} 分`; }
function currencySymbol(code: string) { return ({ CNY: '¥', USD: '$', EUR: '€', GBP: '£', JPY: '¥' } as Record<string,string>)[code] ?? ''; }
function getPeriodSeconds(profile: SalaryData) { if (profile.period === 'hourly') return 3_600; if (profile.period === 'weekly') return Math.max(1, 7 - Math.round(profile.holidayDays / 52)) * profile.workingHours * 3_600; if (profile.period === 'monthly') return Math.max(1, 30 - Math.round(profile.holidayDays / 12)) * profile.workingHours * 3_600; return Math.max(1, 365 - profile.holidayDays) * profile.workingHours * 3_600; }
function getOffWorkMessage(time: string) { const [hours, minutes] = time.split(':').map(Number); const now = new Date(); const end = new Date(now); end.setHours(hours, minutes, 0, 0); const difference = end.getTime() - now.getTime(); if (difference <= 0) return '到点了，请立刻下班 🎉'; const total = Math.ceil(difference / 60_000); return total >= 60 ? `${Math.floor(total / 60)} 小时 ${total % 60} 分` : `${total} 分钟`; }
function encouragement(tone: SalaryData['tone'], mood: Mood, index: number) { const copy: Record<SalaryData['tone'], Record<Mood,string[]>> = {
  gentle: { broken:['今天能坐在这里就已经很了不起，先把下一个十分钟过完。','不是你不够好，是今天真的很难。'], tired:['累了就休息，休息不需要负罪感。','喝口水，放松肩膀，你已经做了很多。'], fine:['不用大放异彩，按时下班也是一场胜利。','工作是手段，生活才是主线。'], good:['状态在线，但别把所有力气都留给公司。','有输出，有喘气，也有准时下班。'], legendary:['今天的你是工位闪电，收工后记得奖励自己。','真正的高手，也知道什么时候合上电脑。'] },
  funny: { broken:['今日 CPU 已过热，允许自己低功耗运行。'], tired:['带薪喘气不是摸鱼，是人类散热。'], fine:['今日目标：平安发育，拒绝白给。'], good:['输出稳定，下班姿势也要稳定。'], legendary:['超神已记录，请勿免费续杯加班。'] },
  calm: { broken:['降低今天的预期，只处理下一件事。'], tired:['注意力已下降，休息是理性选择。'], fine:['维持节奏，到点收工。'], good:['状态良好，保留余量。'], legendary:['今日表现充足，无需额外证明。'] },
  direct: { broken:['今天很难，但你不需要通过硬撑来证明自己。'], tired:['停下来休息，疲惫不是道德问题。'], fine:['做完必要的，然后下班。'], good:['工作有输出，边界也要有。'], legendary:['今天已经足够好，不要用加班稀释它。'] },
}; const options = copy[tone][mood]; return options[index % options.length]; }
