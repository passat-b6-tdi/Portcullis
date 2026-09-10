"use client";

import { useEffect, useState } from "react";
import { usePrivy, useWallets } from "@privy-io/react-auth";
import { createWalletClient, custom } from "viem";
import { CHAIN, EXPLORER, GUARD_ADDRESS } from "@/lib/config";
import { GUARD_ABI, publicClient, readIsGuardian } from "@/lib/guard";
import { shortHex } from "@/lib/format";
import { Card } from "./Card";
import { Check, Cross, External, ShieldAlert, Spinner } from "./icons";

type Tx = { state: "idle" | "pending" | "mined" | "error"; hash?: string; err?: string };

export function GuardianPanel({ paused, onCleared }: { paused: boolean; onCleared: () => void }) {
  const { ready, authenticated, user, login, logout } = usePrivy();
  const { wallets } = useWallets();
  const [isGuardian, setIsGuardian] = useState<boolean | null>(null);
  const [tx, setTx] = useState<Tx>({ state: "idle" });

  const wallet = wallets[0];
  const address = (wallet?.address ?? user?.wallet?.address) as `0x${string}` | undefined;

  useEffect(() => {
    if (!address) {
      setIsGuardian(null);
      return;
    }
    let live = true;
    readIsGuardian(address)
      .then((g) => live && setIsGuardian(g))
      .catch(() => live && setIsGuardian(null));
    return () => {
      live = false;
    };
  }, [address]);

  async function clearBreaker() {
    if (!wallet) return;
    setTx({ state: "pending" });
    try {
      await wallet.switchChain(CHAIN.id);
      const provider = await wallet.getEthereumProvider();
      const walletClient = createWalletClient({
        account: wallet.address as `0x${string}`,
        chain: CHAIN,
        transport: custom(provider)
      });
      const hash = await walletClient.writeContract({
        address: GUARD_ADDRESS,
        abi: GUARD_ABI,
        functionName: "clear"
      });
      setTx({ state: "pending", hash });
      await publicClient.waitForTransactionReceipt({ hash });
      setTx({ state: "mined", hash });
      onCleared();
    } catch (e) {
      setTx({ state: "error", err: e instanceof Error ? e.message : String(e) });
    }
  }

  return (
    <Card
      title="Guardian"
      tone={paused ? "bad" : "neutral"}
      right={
        ready && authenticated ? (
          <button
            onClick={logout}
            className="text-xs text-low transition-colors hover:text-mid"
          >
            sign out
          </button>
        ) : null
      }
    >
      {!ready ? (
        <div className="h-9 w-40 animate-pulse rounded-lg bg-surface-2" />
      ) : !authenticated ? (
        <div className="space-y-3">
          <button
            onClick={login}
            className="w-full rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-emerald-500 active:translate-y-px"
          >
            Connect wallet
          </button>
          <p className="text-xs text-low">
            Guardian actions require a key on the on-chain allowlist. Sign in with a wallet or email.
          </p>
        </div>
      ) : (
        <div className="space-y-3 text-sm">
          <div className="flex items-center justify-between gap-2 rounded-lg border border-hairline bg-surface-2/60 px-3 py-2">
            <span className="font-mono text-xs text-mid">
              {address ? shortHex(address) : "no wallet"}
            </span>
            {isGuardian === true ? (
              <span className="inline-flex items-center gap-1 rounded-full border border-brand/30 bg-brand/10 px-2 py-0.5 text-[11px] text-brand">
                <Check width={11} height={11} />
                Guardian
              </span>
            ) : isGuardian === false ? (
              <span className="rounded-full border border-hairline px-2 py-0.5 text-[11px] text-low">
                Read only
              </span>
            ) : (
              <span className="h-4 w-16 animate-pulse rounded-full bg-surface-2" />
            )}
          </div>

          {!paused ? (
            <p className="text-xs text-low">Breaker nominal. No action required.</p>
          ) : isGuardian ? (
            <button
              onClick={clearBreaker}
              disabled={tx.state === "pending"}
              className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-red-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-red-500 active:translate-y-px disabled:opacity-60"
            >
              {tx.state === "pending" ? (
                <>
                  <Spinner width={15} height={15} />
                  Clearing
                </>
              ) : (
                <>
                  <ShieldAlert width={15} height={15} />
                  Clear breaker
                </>
              )}
            </button>
          ) : (
            <p className="flex items-start gap-2 rounded-lg border border-warn/25 bg-warn/5 px-3 py-2 text-xs text-warn">
              <ShieldAlert width={13} height={13} className="mt-0.5 shrink-0" />
              Breaker is latched. A key on the guardian allowlist must clear it.
            </p>
          )}

          {tx.state === "mined" && (
            <p className="flex items-center gap-1.5 text-xs text-brand">
              <Check width={13} height={13} />
              Cleared.
              {tx.hash && (
                <a
                  className="inline-flex items-center gap-1 underline decoration-brand/40 hover:decoration-brand"
                  href={`${EXPLORER}/tx/${tx.hash}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  {shortHex(tx.hash, 4, 4)}
                  <External width={10} height={10} />
                </a>
              )}
            </p>
          )}
          {tx.state === "error" && (
            <p className="flex items-start gap-1.5 break-all text-xs text-danger">
              <Cross width={13} height={13} className="mt-0.5 shrink-0" />
              {tx.err}
            </p>
          )}
        </div>
      )}
    </Card>
  );
}
