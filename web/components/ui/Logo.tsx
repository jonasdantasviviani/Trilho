export function Logo({ className = '' }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 36 36"
      fill="none"
      className={className}
      aria-label="Trilho logo"
      role="img"
    >
      {/* Horizontal rail */}
      <circle cx="8"  cy="18" r="4" fill="var(--color-accent)" />
      <circle cx="28" cy="18" r="4" fill="var(--color-accent)" />
      <line x1="12" y1="18" x2="24" y2="18" stroke="var(--color-accent)" strokeWidth="2.5" />
      {/* Vertical branch */}
      <circle cx="18" cy="10" r="3" fill="var(--color-primary)" />
      <line x1="18" y1="13" x2="18" y2="17" stroke="var(--color-primary)" strokeWidth="2" />
      <circle cx="18" cy="26" r="3" fill="var(--color-primary)" />
      <line x1="18" y1="19" x2="18" y2="23" stroke="var(--color-primary)" strokeWidth="2" />
    </svg>
  )
}

export function LogoLockup({ className = '' }: { className?: string }) {
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <Logo className="w-7 h-7" />
      <span
        className="text-accent font-extrabold text-sm uppercase"
        style={{ letterSpacing: '0.2em' }}
      >
        TRILHO
      </span>
    </div>
  )
}
