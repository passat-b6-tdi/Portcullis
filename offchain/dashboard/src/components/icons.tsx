import {
  ShieldCheckIcon,
  ShieldWarningIcon,
  CheckIcon,
  XIcon,
  ClockIcon,
  ArrowClockwiseIcon,
  ArrowSquareOutIcon,
  CopyIcon,
  PulseIcon,
  PauseIcon,
  PlayIcon,
  CircleNotchIcon
} from "@phosphor-icons/react/dist/ssr";
import type { IconProps } from "@phosphor-icons/react/dist/lib/types";

export type { IconProps };

export const Shield = (p: IconProps) => <ShieldCheckIcon weight="regular" {...p} />;
export const ShieldAlert = (p: IconProps) => <ShieldWarningIcon weight="fill" {...p} />;
export const Check = (p: IconProps) => <CheckIcon weight="bold" {...p} />;
export const Cross = (p: IconProps) => <XIcon weight="bold" {...p} />;
export const Clock = (p: IconProps) => <ClockIcon weight="regular" {...p} />;
export const Refresh = (p: IconProps) => <ArrowClockwiseIcon weight="bold" {...p} />;
export const External = (p: IconProps) => <ArrowSquareOutIcon weight="regular" {...p} />;
export const Copy = (p: IconProps) => <CopyIcon weight="regular" {...p} />;
export const Activity = (p: IconProps) => <PulseIcon weight="regular" {...p} />;
export const Pause = (p: IconProps) => <PauseIcon weight="fill" {...p} />;
export const Play = (p: IconProps) => <PlayIcon weight="fill" {...p} />;
export const Spinner = (p: IconProps) => (
  <CircleNotchIcon weight="bold" className="animate-spin" {...p} />
);

export function Portcullis({ size = 20, className }: { size?: number; className?: string }) {
  // Lattice gate: three rails, three bars, pointed feet.
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.9}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      <path d="M4 4h16M4 9h16M4 14h16" />
      <path d="M8 4v13M12 4v13M16 4v13" />
      <path d="m8 17-1 3M8 17l1 3M12 17l-1 3M12 17l1 3M16 17l-1 3M16 17l1 3" />
    </svg>
  );
}
