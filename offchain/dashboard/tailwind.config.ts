import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["system-ui", "-apple-system", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "Consolas", "monospace"]
      },
      colors: {
        bg: "rgb(var(--bg) / <alpha-value>)",
        surface: "rgb(var(--surface) / <alpha-value>)",
        "surface-2": "rgb(var(--surface-2) / <alpha-value>)",
        hairline: "rgb(var(--hairline) / <alpha-value>)",
        hi: "rgb(var(--hi) / <alpha-value>)",
        mid: "rgb(var(--mid) / <alpha-value>)",
        low: "rgb(var(--low) / <alpha-value>)",
        brand: "rgb(var(--brand) / <alpha-value>)",
        danger: "rgb(var(--danger) / <alpha-value>)",
        warn: "rgb(var(--warn) / <alpha-value>)"
      },
      keyframes: {
        enter: {
          "0%": { opacity: "0", transform: "translateY(6px)" },
          "100%": { opacity: "1", transform: "translateY(0)" }
        },
        "pulse-ring": {
          "0%, 100%": { opacity: "0.9", transform: "scale(1)" },
          "50%": { opacity: "0", transform: "scale(2.2)" }
        }
      },
      animation: {
        enter: "enter 0.4s cubic-bezier(0.22, 1, 0.36, 1) both",
        "pulse-ring": "pulse-ring 1.8s ease-out infinite"
      }
    }
  },
  plugins: []
} satisfies Config;
