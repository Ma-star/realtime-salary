import { useState } from 'react';
import { z } from 'zod';
import { useForm } from 'react-hook-form';
import type { Control } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Button } from '@/components/ui/button';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  BonusType,
  EncouragementTone,
  Period,
  PrivacyMode,
  SalaryData,
  bonusTypeLabels,
  holidayPresets,
  periodLabels,
  salaryPresets,
} from './types';
import { ArrowRightIcon } from '@radix-ui/react-icons';
import { Popover, PopoverClose, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { BadgePercent, BriefcaseBusiness, LockKeyhole } from 'lucide-react';

const optionalCoefficient = z.string().refine(
  (value) => value === '' || (!Number.isNaN(Number(value)) && Number(value) >= 0 && Number(value) <= 5),
  { message: '请输入 0-5 之间的系数' },
);

const formSchema = z.object({
  amount: z.string().min(1, { message: '请输入薪资金额' }).refine(
    (value) => !Number.isNaN(Number(value)) && Number(value) > 0,
    { message: '请输入有效的正数' },
  ),
  period: z.enum(['yearly', 'monthly', 'weekly', 'hourly']),
  currency: z.string().min(1),
  workingHours: z.string().refine(
    (value) => !Number.isNaN(Number(value)) && Number(value) > 0 && Number(value) <= 24,
    { message: '请输入 1-24 之间的工作时间' },
  ),
  holidayPreset: z.string(),
  customHolidays: z.string().optional(),
  workStartTime: z.string().min(1),
  workEndTime: z.string().min(1),
  breakRule: z.enum(['paid', 'unpaid']),
  overtimeMultiplier: z.string().refine(
    (value) => !Number.isNaN(Number(value)) && Number(value) >= 1 && Number(value) <= 5,
    { message: '加班倍率需在 1-5 之间' },
  ),
  bonusType: z.enum(['none', 'fixed', 'months', 'percentage', 'target']),
  bonusValue: z.string(),
  personalCoefficient: optionalCoefficient,
  companyCoefficient: optionalCoefficient,
  attendanceCoefficient: optionalCoefficient,
  privacyMode: z.enum(['visible', 'masked', 'hidden']),
  tone: z.enum(['gentle', 'funny', 'calm', 'direct']),
});

interface SalaryFormProps {
  onSubmit: (data: SalaryData) => void;
  initialData?: SalaryData | null;
}

export function SalaryForm({ onSubmit, initialData }: SalaryFormProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const usesCustomHolidays = initialData ? ![0, 115].includes(initialData.holidayDays) : false;
  const [showCustomHolidays, setShowCustomHolidays] = useState(usesCustomHolidays);

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      amount: initialData?.amount.toString() ?? '',
      period: initialData?.period ?? 'yearly',
      currency: initialData?.currency ?? 'CNY',
      workingHours: initialData?.workingHours.toString() ?? '8',
      holidayPreset: usesCustomHolidays ? 'custom' : initialData?.holidayDays.toString() ?? '115',
      customHolidays: usesCustomHolidays ? initialData?.holidayDays.toString() : '',
      workStartTime: initialData?.workStartTime ?? '09:00',
      workEndTime: initialData?.workEndTime ?? '18:00',
      breakRule: initialData?.breakPaid ? 'paid' : 'unpaid',
      overtimeMultiplier: initialData?.overtimeMultiplier.toString() ?? '1.5',
      bonusType: initialData?.bonusPlan.type ?? 'none',
      bonusValue: initialData?.bonusPlan.value.toString() ?? '0',
      personalCoefficient: initialData?.bonusPlan.personalCoefficient?.toString() ?? '',
      companyCoefficient: initialData?.bonusPlan.companyCoefficient?.toString() ?? '',
      attendanceCoefficient: initialData?.bonusPlan.attendanceCoefficient?.toString() ?? '',
      privacyMode: initialData?.privacyMode ?? 'masked',
      tone: initialData?.tone ?? 'gentle',
    },
  });

  const bonusType = form.watch('bonusType');

  function handleSubmit(values: z.infer<typeof formSchema>) {
    setIsSubmitting(true);
    const holidayDays = values.holidayPreset === 'custom'
      ? Number(values.customHolidays || 0)
      : Number(values.holidayPreset);
    const coefficient = (value: string) => value === '' ? undefined : Number(value);

    onSubmit({
      amount: Number(values.amount),
      period: values.period as Period,
      currency: values.currency,
      workingHours: Number(values.workingHours),
      holidayDays,
      workStartTime: values.workStartTime,
      workEndTime: values.workEndTime,
      breakPaid: values.breakRule === 'paid',
      overtimeMultiplier: Number(values.overtimeMultiplier),
      bonusPlan: {
        type: values.bonusType as BonusType,
        value: Number(values.bonusValue || 0),
        personalCoefficient: coefficient(values.personalCoefficient),
        companyCoefficient: coefficient(values.companyCoefficient),
        attendanceCoefficient: coefficient(values.attendanceCoefficient),
      },
      privacyMode: values.privacyMode as PrivacyMode,
      tone: values.tone as EncouragementTone,
    });
    setIsSubmitting(false);
  }

  function handlePresetSelect(preset: typeof salaryPresets[number]) {
    form.setValue('amount', preset.amount.toString());
    form.setValue('period', preset.period);
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
        <section className="space-y-4 rounded-2xl border p-4">
          <SectionTitle icon={<BriefcaseBusiness className="h-4 w-4" />} title="基础薪资与班次" subtitle="先算清今天的基础价值" />
          <FormField control={form.control} name="amount" render={({ field }) => (
            <FormItem>
              <FormLabel className="flex items-center justify-between">
                薪资金额
                <Popover>
                  <PopoverTrigger asChild><Button variant="outline" size="sm">快速选择</Button></PopoverTrigger>
                  <PopoverContent className="w-80 p-3" align="end">
                    <div className="grid gap-2">
                      {salaryPresets.map((preset) => (
                        <PopoverClose key={preset.label} asChild>
                          <Button type="button" variant="ghost" className="h-auto w-full justify-start px-2 py-1.5" onClick={() => handlePresetSelect(preset)}>
                            <div className="text-left"><div className="font-medium">{preset.label}</div>{preset.description && <div className="text-xs text-muted-foreground">{preset.description}</div>}</div>
                          </Button>
                        </PopoverClose>
                      ))}
                    </div>
                  </PopoverContent>
                </Popover>
              </FormLabel>
              <FormControl><Input placeholder="例如：120000" type="number" min="1" step="any" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField control={form.control} name="currency" render={({ field }) => (
              <FormItem><FormLabel>货币</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent>
                <SelectItem value="CNY">人民币 (¥)</SelectItem><SelectItem value="USD">美元 ($)</SelectItem><SelectItem value="EUR">欧元 (€)</SelectItem><SelectItem value="GBP">英镑 (£)</SelectItem><SelectItem value="JPY">日元 (¥)</SelectItem>
              </SelectContent></Select><FormMessage /></FormItem>
            )} />
            <FormField control={form.control} name="period" render={({ field }) => (
              <FormItem><FormLabel>计算周期</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent>
                {Object.entries(periodLabels).map(([value, label]) => <SelectItem key={value} value={value}>{label}</SelectItem>)}
              </SelectContent></Select><FormMessage /></FormItem>
            )} />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField control={form.control} name="workStartTime" render={({ field }) => <FormItem><FormLabel>上班时间</FormLabel><FormControl><Input type="time" {...field} /></FormControl><FormMessage /></FormItem>} />
            <FormField control={form.control} name="workEndTime" render={({ field }) => <FormItem><FormLabel>下班时间</FormLabel><FormControl><Input type="time" {...field} /></FormControl><FormMessage /></FormItem>} />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField control={form.control} name="workingHours" render={({ field }) => <FormItem><FormLabel>计划计薪小时</FormLabel><FormControl><Input type="number" min="1" max="24" step="0.5" {...field} /></FormControl><FormMessage /></FormItem>} />
            <FormField control={form.control} name="breakRule" render={({ field }) => (
              <FormItem><FormLabel>休息口径</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent><SelectItem value="unpaid">休息不计薪</SelectItem><SelectItem value="paid">休息照常计薪</SelectItem></SelectContent></Select><FormMessage /></FormItem>
            )} />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField control={form.control} name="overtimeMultiplier" render={({ field }) => <FormItem><FormLabel>临时加班倍率</FormLabel><FormControl><Input type="number" min="1" max="5" step="0.1" {...field} /></FormControl><FormMessage /></FormItem>} />
            <FormField control={form.control} name="holidayPreset" render={({ field }) => (
              <FormItem><FormLabel>年度非工作日</FormLabel><Select onValueChange={(value) => { field.onChange(value); setShowCustomHolidays(value === 'custom'); }} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent>{holidayPresets.map((preset) => <SelectItem key={preset.value.toString()} value={preset.value.toString()}>{preset.label}</SelectItem>)}</SelectContent></Select><FormMessage /></FormItem>
            )} />
          </div>
          {showCustomHolidays && <FormField control={form.control} name="customHolidays" render={({ field }) => <FormItem><FormLabel>自定义非工作日</FormLabel><FormControl><Input type="number" min="0" max="364" {...field} /></FormControl><FormMessage /></FormItem>} />}
        </section>

        <section className="space-y-4 rounded-2xl border p-4">
          <SectionTitle icon={<BadgePercent className="h-4 w-4" />} title="奖金天气" subtitle="预计奖金不冒充已到账" />
          <FormField control={form.control} name="bonusType" render={({ field }) => (
            <FormItem><FormLabel>奖金规则</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent>{Object.entries(bonusTypeLabels).map(([value, label]) => <SelectItem key={value} value={value}>{label}</SelectItem>)}</SelectContent></Select><FormMessage /></FormItem>
          )} />
          {bonusType !== 'none' && <FormField control={form.control} name="bonusValue" render={({ field }) => <FormItem><FormLabel>{bonusType === 'fixed' ? '固定奖金金额' : bonusType === 'months' ? '奖金月数' : '目标比例 (%)'}</FormLabel><FormControl><Input type="number" min="0" step="0.1" {...field} /></FormControl><FormMessage /></FormItem>} />}
          {bonusType === 'target' && (
            <div className="grid gap-3 sm:grid-cols-3">
              <CoefficientField control={form.control} name="personalCoefficient" label="个人系数" />
              <CoefficientField control={form.control} name="companyCoefficient" label="公司系数" />
              <CoefficientField control={form.control} name="attendanceCoefficient" label="出勤系数" />
            </div>
          )}
          {bonusType === 'target' && <p className="text-xs text-muted-foreground">系数未公布时可留空；系统会显示“待公布”，不会偷偷按 1 计算。</p>}
        </section>

        <section className="space-y-4 rounded-2xl border p-4">
          <SectionTitle icon={<LockKeyhole className="h-4 w-4" />} title="隐私与情绪" subtitle="金额默认遮挡，不向外发送" />
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField control={form.control} name="privacyMode" render={({ field }) => (
              <FormItem><FormLabel>默认显示</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent><SelectItem value="visible">直显金额</SelectItem><SelectItem value="masked">伪装金额</SelectItem><SelectItem value="hidden">完全隐身</SelectItem></SelectContent></Select><FormMessage /></FormItem>
            )} />
            <FormField control={form.control} name="tone" render={({ field }) => (
              <FormItem><FormLabel>陪伴语气</FormLabel><Select onValueChange={field.onChange} defaultValue={field.value}><FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl><SelectContent><SelectItem value="gentle">温柔托住</SelectItem><SelectItem value="funny">打工人玩梗</SelectItem><SelectItem value="calm">冷静克制</SelectItem><SelectItem value="direct">直接清醒</SelectItem></SelectContent></Select><FormMessage /></FormItem>
            )} />
          </div>
          <p className="rounded-xl bg-primary/5 p-3 text-xs leading-relaxed text-muted-foreground">你的工资，只给你看。网页会自动清理旧版明文存储；当前标签页内的数据使用 AES-GCM 加密后保存，关闭标签后密钥丢弃。</p>
        </section>

        <Button type="submit" className="w-full" size="lg" disabled={isSubmitting}>
          {initialData ? '保存方案' : '开始今天的班次'} <ArrowRightIcon className="ml-2" />
        </Button>
      </form>
    </Form>
  );
}

function SectionTitle({ icon, title, subtitle }: { icon: React.ReactNode; title: string; subtitle: string }) {
  return <div className="flex items-start gap-2"><span className="mt-0.5 text-primary">{icon}</span><div><h3 className="text-sm font-semibold">{title}</h3><p className="text-xs text-muted-foreground">{subtitle}</p></div></div>;
}

function CoefficientField({ control, name, label }: { control: Control<z.infer<typeof formSchema>>; name: 'personalCoefficient' | 'companyCoefficient' | 'attendanceCoefficient'; label: string }) {
  return <FormField control={control} name={name} render={({ field }) => <FormItem><FormLabel className="text-xs">{label}</FormLabel><FormControl><Input type="number" min="0" max="5" step="0.1" placeholder="待公布" {...field} /></FormControl><FormMessage /></FormItem>} />;
}
