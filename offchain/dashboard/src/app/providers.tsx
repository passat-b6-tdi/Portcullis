"use client";

import { PrivyProvider } from "@privy-io/react-auth";
import { CHAIN, PRIVY_APP_ID } from "@/lib/config";

export function Providers({ children }: { children: React.ReactNode }) {
  if (!PRIVY_APP_ID) {
    return (
      <div className="mx-auto max-w-2xl p-8 text-sm text-amber-300">
        <code>NEXT_PUBLIC_PRIVY_APP_ID</code> is not set. Copy{" "}
        <code>.env.local.example</code> to <code>.env.local</code>.
        {children}
      </div>
    );
  }
  return (
    <PrivyProvider
      appId={PRIVY_APP_ID}
      config={{
        appearance: { theme: "dark", accentColor: "#34d399" },
        defaultChain: CHAIN,
        supportedChains: [CHAIN],
        loginMethods: ["wallet", "email"],
        embeddedWallets: { createOnLogin: "users-without-wallets" }
      }}
    >
      {children}
    </PrivyProvider>
  );
}
