import { adminApiClient } from '@/lib/admin-api'

async function getOverviewStats() {
  try {
    const [users, operational] = await Promise.all([
      adminApiClient<{ total: number; items: { isPremium: boolean }[] }>('/api/admin/users?size=1000'),
      adminApiClient<{ lineStatuses: { currentStatus: string }[] }>('/api/admin/stats/operational'),
    ])
    return {
      totalUsers: users.total,
      premiumUsers: users.items.filter(u => u.isPremium).length,
      queriesToday: 0,
      lineIncidents: operational.lineStatuses.filter(l => l.currentStatus !== 'Normal').length,
    }
  } catch {
    return { totalUsers: 0, premiumUsers: 0, queriesToday: 0, lineIncidents: 0 }
  }
}

export default async function OverviewPage() {
  const stats = await getOverviewStats()
  const cards = [
    { label: 'Total de usuários', value: stats.totalUsers },
    { label: 'Usuários premium', value: stats.premiumUsers },
    { label: 'Consultas hoje', value: stats.queriesToday },
    { label: 'Incidentes nas linhas', value: stats.lineIncidents },
  ]
  return (
    <main className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Visão Geral</h1>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map(c => (
          <div key={c.label} className="rounded-2xl border p-4 space-y-1">
            <p className="text-sm text-gray-500">{c.label}</p>
            <p className="text-3xl font-bold">{c.value}</p>
          </div>
        ))}
      </div>
    </main>
  )
}
