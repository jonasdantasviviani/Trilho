import { adminApiClient } from '@/lib/admin-api'

interface OperationalDto {
  lineStatuses: { code: string; name: string; currentStatus: string }[]
  errorRate: number
}

export default async function OperationalPage() {
  let stats: OperationalDto = { lineStatuses: [], errorRate: 0 }
  try { stats = await adminApiClient('/api/admin/stats/operational') } catch {}
  return (
    <main className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Operacional</h1>
      <div className="grid grid-cols-2 gap-4">
        <div className="rounded-2xl border p-4">
          <p className="text-sm text-gray-500 mb-3">Status das linhas</p>
          <ul className="space-y-2">
            {stats.lineStatuses.map(l => (
              <li key={l.code} className="flex justify-between text-sm">
                <span>{l.name}</span>
                <span className={l.currentStatus === 'Normal' ? 'text-green-600' : 'text-red-600'}>
                  {l.currentStatus}
                </span>
              </li>
            ))}
          </ul>
        </div>
        <div className="rounded-2xl border p-4">
          <p className="text-sm text-gray-500">Taxa de erros da API</p>
          <p className="text-3xl font-bold mt-1">{(stats.errorRate * 100).toFixed(2)}%</p>
        </div>
      </div>
    </main>
  )
}
