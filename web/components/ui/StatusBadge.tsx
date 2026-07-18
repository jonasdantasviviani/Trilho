interface StatusBadgeProps {
  status: string
  className?: string
}

const statusStyles: Record<string, string> = {
  Normal:     'text-success bg-success/10',
  Parcial:    'text-warning bg-warning/10',
  Paralisada: 'text-danger bg-danger/10',
  'Em obras': 'text-warning bg-warning/10',
}

export function StatusBadge({ status, className = '' }: StatusBadgeProps) {
  const style = statusStyles[status] ?? 'text-text-secondary bg-surface-raised'
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold ${style} ${className}`}>
      {status}
    </span>
  )
}
