import type { Tone } from "@/lib/format";

const BAR: Record<Tone, string> = {
  neutral: "bg-hairline",
  ok: "bg-brand",
  bad: "bg-danger",
  warn: "bg-warn"
};

export function Card({
  title,
  subtitle,
  right,
  tone = "neutral",
  children
}: {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
  tone?: Tone;
  children: React.ReactNode;
}) {
  return (
    <section className="relative overflow-hidden rounded-xl border border-hairline bg-surface/60">
      <span className={`absolute inset-x-0 top-0 h-px ${BAR[tone]} opacity-60`} />
      <header className="flex items-baseline justify-between gap-3 border-b border-hairline/70 px-4 py-3">
        <div className="min-w-0">
          <h2 className="text-sm font-medium text-hi">{title}</h2>
          {subtitle ? <p className="mt-0.5 truncate text-xs text-low">{subtitle}</p> : null}
        </div>
        {right}
      </header>
      <div className="p-4">{children}</div>
    </section>
  );
}
