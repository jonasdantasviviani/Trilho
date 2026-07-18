import { StatusBadge } from './ui/StatusBadge'

interface LineStatus {
  code: string
  name: string
  currentStatus: string
  statusMessage: string | null
}

export function LineStatusTicker({ lines }: { lines: LineStatus[] }) {
  if (lines.length === 0) {
    return (
      <p className="text-sm text-text-secondary text-center py-2">
        Status das linhas temporariamente indisponível
      </p>
    )
  }

  return (
    <div className="flex flex-wrap gap-2 justify-center">
      {lines.map((l) => (
        <div
          key={l.code}
          className="flex items-center gap-2 rounded-full border border-border bg-surface px-3 py-1.5 text-sm"
        >
          <span className="font-semibold text-text-primary">{l.name}</span>
          <StatusBadge status={l.currentStatus} />
        </div>
      ))}
    </div>
  )
}
