import { EXPLORER, GUARD_ADDRESS } from "@/lib/config";
import { fmtValue, shortHex } from "@/lib/format";
import type { GuardConfig } from "@/lib/subgraph";
import { Card } from "./Card";
import { CopyButton } from "./CopyButton";

const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

function Row({ k, v }: { k: string; v: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-2 text-sm">
      <span className="shrink-0 text-xs text-low">{k}</span>
      <span className="min-w-0 truncate text-right font-mono text-xs text-hi">{v}</span>
    </div>
  );
}

function Group({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="py-1 first:pt-0 last:pb-0">
      <div className="pb-1 text-xs text-low">{label}</div>
      <div className="divide-y divide-hairline/40">{children}</div>
    </div>
  );
}

export function ConfigCard({
  config,
  sources,
  tokens,
  payoutCount,
  rejectionCount
}: {
  config: GuardConfig | null;
  sources: { id: string; enrolled: boolean }[];
  tokens: { id: string; allowed: boolean; decimals: number }[];
  payoutCount: number;
  rejectionCount: number;
}) {
  const zero = "n/a";
  const enrolled = sources.filter((s) => s.enrolled).length;
  const allowed = tokens.filter((t) => t.allowed);
  const hasPolicy = config?.policy && config.policy !== ZERO_ADDR;

  return (
    <Card title="Guard config">
      <div className="divide-y divide-hairline/50">
        <Group label="Instance">
          <Row
            k="guard"
            v={
              <span className="inline-flex items-center gap-1.5">
                <a
                  className="transition-colors hover:text-brand"
                  href={`${EXPLORER}/address/${GUARD_ADDRESS}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  {shortHex(GUARD_ADDRESS)}
                </a>
                <CopyButton value={GUARD_ADDRESS} label="Copy guard address" />
              </span>
            }
          />
        </Group>

        <Group label="Limits">
          <Row
            k="bounds, 18dp"
            v={config?.minValue ? `${fmtValue(config.minValue)} to ${fmtValue(config.maxValue!)}` : zero}
          />
          <Row
            k="rate"
            v={
              config?.rateCapacity
                ? `${fmtValue(config.rateCapacity)} @ ${fmtValue(config.rateRefillPerSec!)}/s`
                : zero
            }
          />
          <Row
            k="volume spike"
            v={
              config?.spikeFactorBps
                ? `${Number(config.spikeFactorBps) / 10000}x over ${config.warmup ?? "?"} obs`
                : zero
            }
          />
        </Group>

        <Group label="Policy and registry">
          <Row
            k="CRE policy"
            v={
              hasPolicy ? (
                <a
                  className="transition-colors hover:text-brand"
                  href={`${EXPLORER}/address/${config!.policy}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  {shortHex(config!.policy!)}
                </a>
              ) : (
                <span className="text-low">none</span>
              )
            }
          />
          <Row k="enrolled sources" v={enrolled || zero} />
          <Row
            k="allowed tokens"
            v={allowed.length ? allowed.map((t) => shortHex(t.id, 4, 4)).join(", ") : zero}
          />
        </Group>

        <Group label="Throughput">
          <Row
            k="payouts / rejections"
            v={
              <>
                <span className="text-brand">{payoutCount}</span>
                <span className="text-low"> / </span>
                <span className={rejectionCount ? "text-warn" : "text-low"}>{rejectionCount}</span>
              </>
            }
          />
        </Group>
      </div>
    </Card>
  );
}
