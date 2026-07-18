interface LineChipProps {
  code: string
  color: string
  selected?: boolean
  onClick?: () => void
}

function getTextColor(hex: string): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  return lum > 0.5 ? '#0A0A14' : '#FFFFFF'
}

export function LineChip({ code, color, selected = false, onClick }: LineChipProps) {
  return (
    <button
      onClick={onClick}
      style={{ backgroundColor: color, color: getTextColor(color) }}
      className={[
        'inline-flex items-center px-2 py-0.5 rounded-md text-[9px] font-bold',
        'transition-all duration-150',
        selected ? 'ring-2 ring-accent ring-offset-1 ring-offset-bg' : '',
      ].join(' ')}
      aria-pressed={selected}
    >
      {code}
    </button>
  )
}
