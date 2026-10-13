import { useEffect, useState } from 'react';
import { SalaryForm } from './salary-form';
import { EarningsDisplay } from './earnings-display';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { ModeToggle } from '../mode-toggle';
import { SalaryData } from './types';
import { Github, LoaderCircle, ShieldCheck, Sparkles } from 'lucide-react';
import { Button } from '../ui/button';
import { clearPrivateVault, migrateLegacyLocalStorage, readPrivateRecord, writePrivateRecord } from '@/lib/private-vault';

const PROFILE_RECORD_ID = 'salary-profile';
const LEGACY_PROFILE_KEY = 'realtime-salary-profile';

export function SalaryCalculator() {
  const [salaryData, setSalaryData] = useState<SalaryData | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function restoreProfile() {
      const migrated = await migrateLegacyLocalStorage<Partial<SalaryData>>(LEGACY_PROFILE_KEY, PROFILE_RECORD_ID);
      const saved = migrated ?? await readPrivateRecord<Partial<SalaryData>>(PROFILE_RECORD_ID);
      if (cancelled) return;
      const normalized = saved ? normalizeSalaryData(saved) : null;
      setSalaryData(normalized);
      setIsEditing(!normalized);
      setIsLoading(false);
      if (normalized) await writePrivateRecord(PROFILE_RECORD_ID, normalized);
    }
    void restoreProfile();
    return () => { cancelled = true; };
  }, []);

  function handleSave(data: SalaryData) {
    void writePrivateRecord(PROFILE_RECORD_ID, data);
    setSalaryData(data);
    setIsEditing(false);
  }

  async function handleEraseAll() {
    await clearPrivateVault();
    localStorage.removeItem(LEGACY_PROFILE_KEY);
    setSalaryData(null);
    setIsEditing(true);
  }
  
  return (
    <Card className="w-full max-w-2xl mx-auto overflow-hidden border-white/60 bg-card/95 shadow-2xl shadow-primary/10 backdrop-blur">
      <CardHeader className="relative">
        <div className="absolute right-4 top-4 flex items-center gap-2">
          <Button
            variant="ghost"
            size="icon"
            asChild
          >
            <a
              href="https://github.com/mereithhh/realtime-salary"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:no-underline"
            >
              <Github className="h-[1.2rem] w-[1.2rem]" />
              <span className="sr-only">GitHub repository</span>
            </a>
          </Button>
          <ModeToggle />
        </div>
        <div className="mb-2 flex w-fit items-center gap-1.5 rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
          <Sparkles className="h-3.5 w-3.5" /> 下班回血器
        </div>
        <CardTitle className="text-2xl font-bold tracking-tight">今天的努力，正在兑现</CardTitle>
        <CardDescription>
          不只数钱，也记录每一秒认真生活的你。
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="flex min-h-64 flex-col items-center justify-center gap-3 text-muted-foreground">
            <LoaderCircle className="h-7 w-7 animate-spin text-primary" />
            <p className="text-sm">正在打开你的本地隐私保险箱…</p>
          </div>
        ) : !salaryData || isEditing ? (
          <SalaryForm onSubmit={handleSave} initialData={salaryData} />
        ) : (
          <EarningsDisplay 
            salaryData={salaryData} 
            onReset={() => setIsEditing(true)}
            onEraseAll={() => void handleEraseAll()}
          />
        )}
        {!isLoading && (
          <div className="mt-5 flex items-center justify-center gap-1.5 text-[11px] text-muted-foreground">
            <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
            当前标签页加密 · 旧版 localStorage 明文已自动清理
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function normalizeSalaryData(saved: Partial<SalaryData>): SalaryData {
  return {
    amount: saved.amount ?? 120_000,
    period: saved.period ?? 'yearly',
    currency: saved.currency ?? 'CNY',
    workingHours: saved.workingHours ?? 8,
    holidayDays: saved.holidayDays ?? 115,
    workStartTime: saved.workStartTime ?? '09:00',
    workEndTime: saved.workEndTime ?? '18:00',
    breakPaid: saved.breakPaid ?? false,
    overtimeMultiplier: saved.overtimeMultiplier ?? 1.5,
    bonusPlan: saved.bonusPlan ?? { type: 'none', value: 0 },
    privacyMode: saved.privacyMode ?? 'masked',
    tone: saved.tone ?? 'gentle',
  };
}
