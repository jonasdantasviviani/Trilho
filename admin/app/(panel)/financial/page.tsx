import { adminApiClient } from '@/lib/admin-api'

export default async function FinancialPage() {
  let stats = { mrr: 0, newSubscribers: 0, churn: 0, period: '' }
  try { stats = await adminApiClient('/api/admin/stats/financial') } catch {}
  return (
    <main className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Financeiro</h1>
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'MRR', value: `R$ ${stats.mrr.toFixed(2)}` },
          { label: 'Novos assinantes', value: stats.newSubscribers },
          { label: 'Churn', value: stats.churn },
        ].map(c => (
          <div key={c.label} className="rounded-2xl border p-4">
            <p className="text-sm text-gray-500">{c.label}</p>
            <p className="text-2xl font-bold mt-1">{c.value}</p>
          </div>
        ))}
      </div>
      <p className="text-xs text-gray-400">Período: {stats.period || '—'}</p>
    </main>
  )
}
