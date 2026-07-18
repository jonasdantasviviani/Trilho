interface CrowdBarProps {
  density: number // 0–1
  className?: string
}

function crowdColor(d: number): string {
  if (d < 0.20) return 'var(--crowd-empty)'
  if (d < 0.40) return 'var(--crowd-low)'
  if (d < 0.60) return 'var(--crowd-moderate)'
  if (d < 0.80) return 'var(--crowd-high)'
  return 'var(--crowd-full)'
}

export function CrowdBar({ density, className = '' }: CrowdBarProps) {
  const clamped = Math.min(1, Math.max(0, density))
  return (
    <div
      className={`w-full rounded-full overflow-hidden bg-surface-raised h-2 ${className}`}
      role="meter"
      aria-valuenow={Math.round(clamped * 100)}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      <div
        data-testid="crowd-fill"
        className="h-full rounded-full transition-all duration-300"
        style={{ width: `${clamped * 100}%`, backgroundColor: crowdColor(clamped) }}
      />
    </div>
  )
}
