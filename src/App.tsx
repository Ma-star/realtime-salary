import { ThemeProvider } from '@/components/theme-provider';
import { SalaryCalculator } from '@/components/salary-calculator';
import './App.css';

function App() {
  return (
    <ThemeProvider defaultTheme="light" storageKey="salary-calculator-theme">
      <div className="relative min-h-screen overflow-hidden bg-background px-4 py-8 sm:py-12">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-[32rem] bg-[radial-gradient(circle_at_top_left,hsl(var(--primary)/0.18),transparent_45%),radial-gradient(circle_at_top_right,hsl(270_80%_60%/0.12),transparent_40%)]" />
        <div className="relative flex min-h-[calc(100vh-4rem)] items-center justify-center">
        <SalaryCalculator />
        </div>
      </div>
    </ThemeProvider>
  );
}

export default App;
