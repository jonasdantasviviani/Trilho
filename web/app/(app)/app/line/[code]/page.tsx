import { apiClient } from '@/lib/api'
import { cookies } from 'next/headers'
import { notFound } from 'next/navigation'
import { COOKIE_NAME } from '@/lib/auth'

interface LineStatusDto {
  code: string; name: string; currentStatus: string; statusMessage: string | null
  stations: { id: number; name: string; densityLevel: string; density: number }[]
}

const densityColor: Record<string, string> = {
  Low: 'bg-green-400', Moderate: 'bg-yellow-400',
  High: 'bg-orange-500', VeryHigh: 'bg-red-500',
}

export default async function LinePage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params
  const cookieStore = await cookies()
  const cookie = cookieStore.get(COOKIE_NAME)?.value

  let line: LineStatusDto
  try {
    line = await apiClient<LineStatusDto>(`/api/lines/${code}/status`, {
      cookie: cookie ? `${COOKIE_NAME}=${cookie}` : undefined,
    })
  } catch {
    notFound()
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-8 space-y-6">
      <div className={`rounded-xl p-4 ${line.currentStatus === 'Normal' ? 'bg-green-50 border border-green-200' : 'bg-yellow-50 border border-yellow-200'}`}>
        <h1 className="text-xl font-bold">{line.name}</h1>
        <p className="text-sm font-medium mt-1">{line.currentStatus}{line.statusMessage ? ` — ${line.statusMessage}` : ''}</p>
      </div>

      <ul className="space-y-2">
        {line.stations.map(s => (
          <li key={s.id} className="flex items-center justify-between rounded-xl border px-4 py-3">
            <span className="text-sm font-medium">{s.name}</span>
            <span className={`w-3 h-3 rounded-full ${densityColor[s.densityLevel] ?? 'bg-gray-400'}`} />
          </li>
        ))}
      </ul>
    </main>
  )
}
