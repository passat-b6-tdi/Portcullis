import { Shield, ShieldAlert } from "./icons";

export function StatusPill({ paused, reason }: { paused: boolean; reason?: string | null }) {
  if (!paused) {
    return (
      <span className="inline-flex items-center gap-1.5 rounded-full border border-brand/40 bg-brand/10 px-3 py-1 text-xs font-medium text-brand">
        <Shield width={13} height={13} />
        Breaker up
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-danger/50 bg-danger/10 px-3 py-1 text-xs font-medium text-danger">
      <span className="relative flex h-2 w-2 items-center justify-center">
        <span className="absolute inline-flex h-2 w-2 animate-pulse-ring rounded-full bg-danger" />
        <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-danger" />
      </span>
      Latched
      {reason && reason !== "NONE" ? (
        <span className="font-mono text-[11px] text-danger/80">{reason}</span>
      ) : (
        <ShieldAlert width={13} height={13} />
      )}
    </span>
  );
}
