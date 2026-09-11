"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { CHAIN, EXPLORER, GUARD_ADDRESS, SUBGRAPH_URL } from "@/lib/config";
import { readGuardStatus } from "@/lib/guard";
import { fetchOverview, type Overview } from "@/lib/subgraph";
import { shortHex } from "@/lib/format";
import { StatusPill } from "@/components/StatusPill";
import { StatStrip, type Stat } from "@/components/StatStrip";
import { GuardianPanel } from "@/components/GuardianPanel";
import { VerdictFeed } from "@/components/VerdictFeed";
import { SentinelTimeline } from "@/components/SentinelTimeline";
import { ConfigCard } from "@/components/ConfigCard";
import { CopyButton } from "@/components/CopyButton";
import { Clock, External, Pause, Play, Portcullis, Refresh } from "@/components/icons";

const POLL_MS = 15_000;

export default function Page() {
  const [paused, setPaused] = useState(false);
  const [chainReason, setChainReason] = useState<string | null>(null);
  const [data, setData] = useState<Overview | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [live, setLive] = useState(true);
  const [syncedAt, setSyncedAt] = useState<number | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const busy = useRef(false);

  const refresh = useCallback(async () => {
    if (busy.current) return;
    busy.current = true;
    try {
      const status = await readGuardStatus();
      setPaused(status.paused);
      if (SUBGRAPH_URL) {
        const ov = await fetchOverview();
        setData(ov);
        const lastTrip = ov.sentinelEvents.find((e) => e.kind === "TRIPPED");
        setChainReason(ov.config?.lastReason ?? lastTrip?.reason ?? null);
      }
      setErr(null);
      setSyncedAt(Date.now());
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
      busy.current = false;
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  useEffect(() => {
    if (!live) return;
    const t = setInterval(refresh, POLL_MS);
    return () => clearInterval(t);
  }, [live, refresh]);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  const syncAge = syncedAt ? Math.max(0, Math.floor((now - syncedAt) / 1000)) : null;
  const settlements = data?.settlements ?? [];
  const passed = settlements.filter((s) => s.cleared).length;
  const enrolled = (data?.sources ?? []).filter((s) => s.enrolled).length;
  const rejections = data?.rejectionCount ?? 0;

  const stats: Stat[] = [
    {
      label: "Breaker",
      value: paused ? "Latched" : "Up",
      tone: paused ? "bad" : "ok",
      hint: paused ? chainReason ?? "authenticated anomaly" : "no external calls on write path"
    },
    {
      label: "Settlements paid",
      value: data ? data.payoutCount : "…",
      tone: "ok",
      hint: settlements.length ? `${passed} cleared in last ${settlements.length}` : "from subgraph"
    },
    {
      label: "Rejections",
      value: data ? rejections : "…",
      tone: rejections ? "warn" : "neutral",
      hint: "dropped before value moved"
    },
    {
      label: "Enrolled sources",
      value: data ? enrolled : "…",
      hint: "identity-bound authorities"
    }
  ];

  return (
    <main className="mx-auto max-w-5xl px-5 py-8 sm:py-10">
      <header className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="grid h-9 w-9 place-items-center rounded-lg border border-brand/30 bg-brand/10 text-brand">
            <Portcullis size={20} />
          </span>
          <div>
            <h1 className="text-sm font-semibold tracking-tight text-hi">Portcullis</h1>
            <p className="text-xs text-low">Guardian console</p>
          </div>
        </div>

        <div className="flex flex-col items-end gap-2">
          <StatusPill paused={paused} reason={chainReason} />
          <div className="flex items-center gap-2 font-mono text-[11px] text-low">
            <span className="text-mid">{CHAIN.name}</span>
            <a
              className="inline-flex items-center gap-1 transition-colors hover:text-hi"
              href={`${EXPLORER}/address/${GUARD_ADDRESS}`}
              target="_blank"
              rel="noreferrer"
            >
              {shortHex(GUARD_ADDRESS)}
              <External width={10} height={10} />
            </a>
            <CopyButton value={GUARD_ADDRESS} label="Copy guard address" />
          </div>
        </div>
      </header>

      {err && (
        <div className="mb-6 rounded-lg border border-danger/30 bg-danger/10 px-4 py-2.5 font-mono text-xs text-danger">
          {err}
        </div>
      )}

      <div className="mb-6">
        <StatStrip items={stats} />
      </div>

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3 border-y border-hairline/60 py-2 text-[11px] text-low">
        <span className="inline-flex items-center gap-1.5">
          <Clock width={12} height={12} />
          {loading && !data
            ? "syncing"
            : syncAge === null
              ? "not synced"
              : `updated ${syncAge}s ago`}
        </span>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setLive((v) => !v)}
            className="inline-flex items-center gap-1.5 rounded border border-hairline bg-surface-2 px-2 py-1 transition-colors hover:text-mid"
          >
            {live ? <Pause width={11} height={11} /> : <Play width={11} height={11} />}
            {live ? "Pause" : "Resume"}
          </button>
          <button
            onClick={refresh}
            className="inline-flex items-center gap-1.5 rounded border border-hairline bg-surface-2 px-2 py-1 transition-colors hover:text-mid"
          >
            <Refresh width={11} height={11} />
            Refresh
          </button>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <div className="animate-enter space-y-4 md:col-span-2">
          <VerdictFeed
            rows={settlements}
            ensNames={{}}
            live={live}
            tokenDecimals={Object.fromEntries(
              (data?.tokens ?? []).map((t) => [t.id.toLowerCase(), t.decimals])
            )}
          />
          <SentinelTimeline rows={data?.sentinelEvents ?? []} />
        </div>
        <div className="animate-enter space-y-4" style={{ animationDelay: "60ms" }}>
          <GuardianPanel paused={paused} onCleared={refresh} />
          <ConfigCard
            config={data?.config ?? null}
            sources={data?.sources ?? []}
            tokens={data?.tokens ?? []}
            payoutCount={data?.payoutCount ?? 0}
            rejectionCount={data?.rejectionCount ?? 0}
          />
        </div>
      </div>

      <footer className="mt-10 flex flex-wrap items-center gap-2 font-mono text-[11px] text-low">
        {data?.indexedBlock ? (
          <span>subgraph at block {data.indexedBlock}</span>
        ) : (
          <span>subgraph not configured</span>
        )}
        {data?.indexingErrors ? (
          <span className="rounded border border-warn/30 bg-warn/10 px-1.5 py-0.5 text-warn">
            indexing errors
          </span>
        ) : null}
        <a
          href="https://b0gdaniy.gitbook.io/portcullis-guard"
          target="_blank"
          rel="noreferrer"
          className="ml-auto inline-flex items-center gap-1 text-low hover:text-hi"
        >
          docs
          <External width={11} height={11} />
        </a>
      </footer>
    </main>
  );
}
