import { EXPLORER } from "@/lib/config";
import { fmtAge, shortHex } from "@/lib/format";
import type { SentinelEvent } from "@/lib/subgraph";
import { Card } from "./Card";
import { Check } from "./icons";

export function SentinelTimeline({ rows }: { rows: SentinelEvent[] }) {
  const lastTrip = rows.find((e) => e.kind === "TRIPPED");

  return (
    <Card
      title="Circuit breaker"
      subtitle={
        rows.length ? `${rows.length} transition${rows.length > 1 ? "s" : ""} on record` : undefined
      }
    >
      {rows.length === 0 ? (
        <div className="flex items-center gap-2 py-6 text-sm text-low">
          <span className="grid h-6 w-6 place-items-center rounded-full border border-brand/30 bg-brand/10 text-brand">
            <Check width={13} height={13} />
          </span>
          Breaker has never latched.
        </div>
      ) : (
        <ul className="relative space-y-4 pl-1 before:absolute before:left-[6px] before:top-2 before:bottom-2 before:w-px before:bg-hairline">
          {rows.map((e) => {
            const tripped = e.kind === "TRIPPED";
            return (
              <li key={e.id} className="relative pl-6">
                <span
                  className={`absolute left-0 top-1 h-[13px] w-[13px] rounded-full border-2 border-bg ${
                    tripped ? "bg-danger" : "bg-brand"
                  } ${tripped && e.id === lastTrip?.id ? "ring-2 ring-danger/25" : ""}`}
                  aria-hidden="true"
                />
                <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                  <span
                    className={`text-xs font-medium ${tripped ? "text-danger" : "text-brand"}`}
                  >
                    {tripped ? "Tripped" : "Cleared"}
                  </span>
                  {e.reason && e.reason !== "NONE" ? (
                    <span className="rounded border border-hairline bg-surface-2 px-1.5 py-0.5 font-mono text-[10px] text-mid">
                      {e.reason}
                    </span>
                  ) : null}
                </div>
                <div className="mt-1 font-mono text-[11px] text-low">
                  {fmtAge(e.blockTimestamp)} by {shortHex(e.actor)}{" "}
                  <a
                    className="text-low transition-colors hover:text-hi"
                    href={`${EXPLORER}/tx/${e.txHash}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    tx
                  </a>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}
