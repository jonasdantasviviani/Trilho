import { apiClient } from '@/lib/api'
import { cookies } from 'next/headers'
import { notFound } from 'next/navigation'
import { COOKIE_NAME } from '@/lib/auth'

interface CrowdDto {
  stationId: number; stationName: string
  density: number; densityLevel: string
  source: string; capturedAt: string
  history: { density: number; level: string; capturedAt: string }[]
}

export default async function StationPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const cookieStore = await cookies()
  const cookie = cookieStore.get(COOKIE_NAME)?.value

  let crowd: CrowdDto
  try {
    crowd = await apiClient<CrowdDto>(`/api/stations/${id}/crowd`, {
      cookie: cookie ? `${COOKIE_NAME}=${cookie}` : undefined,
    })
  } catch {
    notFound()
  }

  const pct = Math.round(crowd.density * 100)

  return (
    <main className="max-w-lg mx-auto px-4 py-8 space-y-6">
      <h1 className="text-2xl font-bold">{crowd.stationName}</h1>

      <div className="rounded-2xl border p-6 text-center space-y-2">
        <p className="text-5xl font-bold">{pct}%</p>
        <p className="text-sm text-gray-500 uppercase tracking-wide">{crowd.densityLevel}</p>
        <div className="w-full bg-gray-100 rounded-full h-2 mt-2">
          <div
            className="h-2 rounded-full bg-blue-500 transition-all"
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>

      <div className="space-y-1">
        <h2 className="text-sm font-semibold text-gray-500 uppercase">Últimas 3h</h2>
        <div className="flex items-end gap-1 h-16">
          {crowd.history.slice(-18).map((h, i) => (
            <div
              key={i}
              className="flex-1 bg-blue-200 rounded-t"
              style={{ height: `${Math.round(h.density * 100)}%` }}
              title={`${Math.round(h.density * 100)}%`}
            />
          ))}
        </div>
      </div>

      <p className="text-xs text-gray-400 text-center">
        Fonte: {crowd.source} · Atualizado {new Date(crowd.capturedAt).toLocaleTimeString('pt-BR')}
      </p>
    </main>
  )
}
