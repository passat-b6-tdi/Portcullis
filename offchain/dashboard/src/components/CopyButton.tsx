"use client";

import { useState } from "react";
import { Check, Copy } from "./icons";

export function CopyButton({ value, label }: { value: string; label?: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1200);
    } catch {
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      aria-label={label ?? `Copy ${value}`}
      className="inline-grid h-5 w-5 place-items-center rounded text-low transition-colors hover:bg-white/[0.06] hover:text-mid"
    >
      {copied ? <Check width={12} height={12} /> : <Copy width={12} height={12} />}
    </button>
  );
}
