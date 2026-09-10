import { EXPLORER } from "@/lib/config";
import { fmtAge, fmtValue, shortHex, verdict } from "@/lib/format";
import type { Settlement } from "@/lib/subgraph";
import { Card } from "./Card";
import { External } from "./icons";

export function VerdictFeed({
  rows,
  ensNames,
  tokenDecimals,
  live = true
}: {
  rows: Settlement[];
  ensNames: Record<string, string>;
  tokenDecimals: Record<string, number>;
  live?: boolean;
}) {
  const passed = rows.filter((s) => s.cleared).length;

  return (
    <Card
      title="Verdict feed"
      subtitle={rows.length ? `${passed} cleared / ${rows.length - passed} rejected` : undefined}
      right={
        <span className="inline-flex items-center gap-1.5 text-[11px] text-low">
          <span
            className={`h-1.5 w-1.5 rounded-full ${live ? "bg-brand" : "bg-low"}`}
            aria-hidden="true"
          />
          {live ? "live" : "paused"}
        </span>
      }
    >
      {rows.length === 0 ? (
        <p className="py-6 text-center text-sm text-low">No settlements indexed yet.</p>
      ) : (
        <div className="-mx-4 -mb-4 overflow-x-auto">
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="text-left text-[11px] text-low">
                <th className="px-4 py-2 font-normal">When</th>
                <th className="px-2 py-2 font-normal">Source</th>
                <th className="px-2 py-2 text-right font-normal">Value</th>
                <th className="px-2 py-2 font-normal">Verdict</th>
                <th className="px-4 py-2 text-right font-normal">Tx</th>
              </tr>
            </thead>
            <tbody className="font-mono text-xs">
              {rows.map((s) => {
                const v = verdict(s.cleared, s.reason);
                return (
                  <tr
                    key={s.id}
                    className="border-t border-hairline/60 transition-colors hover:bg-white/[0.02]"
                  >
                    <td className={`border-l-2 px-4 py-2.5 text-mid ${v.edge}`}>
                      {fmtAge(s.blockTimestamp)}
                    </td>
                    <td className="px-2 py-2.5 text-hi">
                      {ensNames[s.srcId.toLowerCase()] ?? shortHex(s.srcId)}
                    </td>
                    <td className="px-2 py-2.5 text-right tabular-nums text-hi">
                      {fmtValue(s.value, tokenDecimals[s.token.toLowerCase()] ?? 18)}
                    </td>
                    <td className="px-2 py-2.5">
                      <span className={`inline-block rounded border px-1.5 py-0.5 text-[11px] ${v.chip}`}>
                        {v.label}
                      </span>
                    </td>
                    <td className="px-4 py-2.5 text-right">
                      <a
                        className="inline-flex items-center gap-1 text-low transition-colors hover:text-hi"
                        href={`${EXPLORER}/tx/${s.txHash}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {shortHex(s.txHash, 4, 4)}
                        <External width={11} height={11} />
                      </a>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
