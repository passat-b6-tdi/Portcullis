import type { Tone } from "@/lib/format";

const VALUE: Record<Tone, string> = {
  neutral: "text-hi",
  ok: "text-brand",
  bad: "text-danger",
  warn: "text-warn"
};

export type Stat = {
  label: string;
  value: React.ReactNode;
  hint?: string;
  tone?: Tone;
};

export function StatStrip({ items }: { items: Stat[] }) {
  return (
    <div className="grid grid-cols-2 divide-x divide-y divide-hairline overflow-hidden rounded-xl border border-hairline bg-surface/60 sm:grid-cols-4 sm:divide-y-0">
      {items.map((s) => (
        <div key={s.label} className="px-4 py-3">
          <div className="text-xs text-low">{s.label}</div>
          <div className={`mt-1 font-mono text-lg font-semibold tabular-nums ${VALUE[s.tone ?? "neutral"]}`}>
            {s.value}
          </div>
          {s.hint ? <div className="mt-0.5 truncate text-[11px] text-low">{s.hint}</div> : null}
        </div>
      ))}
    </div>
  );
}
