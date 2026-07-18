import { adminApiClient } from '@/lib/admin-api'

interface SourceHealth {
  source: string
  status: 'Healthy' | 'Degraded' | 'Stale' | 'Down'
  ageLabel: string
  ageSeconds: number
  lastError: string | null
}

interface HealthResponse {
  sources: SourceHealth[]
  checkedAt: string
}

const statusConfig: Record<string, { label: string; dot: string; text: string }> = {
  Healthy:  { label: 'Healthy',  dot: 'bg-green-500',  text: 'text-green-700 dark:text-green-400' },
  Degraded: { label: 'Degraded', dot: 'bg-yellow-500', text: 'text-yellow-700 dark:text-yellow-400' },
  Stale:    { label: 'Stale',    dot: 'bg-orange-400', text: 'text-orange-700 dark:text-orange-400' },
  Down:     { label: 'Down',     dot: 'bg-red-500',    text: 'text-red-700 dark:text-red-400' },
}

export default async function HealthPage() {
  let data: HealthResponse = { sources: [], checkedAt: new Date().toISOString() }
  let fetchError = false

  try {
    data = await adminApiClient<HealthResponse>('/api/admin/health/sources')
  } catch {
    fetchError = true
  }

  const overallOk = !fetchError && data.sources.every(s => s.status === 'Healthy')

  return (
    <main className="p-6 space-y-6">
      <div className="flex items-center gap-3">
        <h1 className="text-2xl font-bold">Saúde das Fontes de Dados</h1>
        <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${
          fetchError
            ? 'bg-red-100 text-red-700'
            : overallOk
              ? 'bg-green-100 text-green-700'
              : 'bg-yellow-100 text-yellow-700'
        }`}>
          {fetchError ? 'ERRO AO BUSCAR' : overallOk ? 'TUDO OK' : 'ATENÇÃO'}
        </span>
      </div>

      {fetchError && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Não foi possível conectar ao backend. Verifique se a API está rodando.
        </div>
      )}

      {!fetchError && data.sources.length === 0 && (
        <div className="rounded-xl border p-6 text-center text-gray-500 text-sm">
          Nenhum dado ainda — os workers ainda não completaram o primeiro ciclo.
          <br />
          Aguarde até 2 minutos após o backend iniciar.
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {data.sources.map((source) => {
          const cfg = statusConfig[source.status] ?? statusConfig.Down
          const isStale = source.ageSeconds > 300 // > 5 min
          return (
            <div
              key={source.source}
              className={`rounded-2xl border p-4 space-y-2 ${
                source.status === 'Down' ? 'border-red-200 bg-red-50 dark:bg-red-950/20' : ''
              }`}
            >
              {/* Header */}
              <div className="flex items-center justify-between">
                <span className="font-semibold text-sm">{source.source}</span>
                <div className="flex items-center gap-1.5">
                  <div className={`w-2 h-2 rounded-full ${cfg.dot}`} />
                  <span className={`text-xs font-medium ${cfg.text}`}>{cfg.label}</span>
                </div>
              </div>

              {/* Age */}
              <p className={`text-xs ${isStale ? 'text-orange-600 font-medium' : 'text-gray-500'}`}>
                {isStale ? '⚠ ' : ''}Última atualização: {source.ageLabel}
              </p>

              {/* Error message */}
              {source.lastError && (
                <p className="text-xs text-red-600 bg-red-50 dark:bg-red-900/30 rounded-lg px-3 py-2 font-mono break-words">
                  {source.lastError}
                </p>
              )}
            </div>
          )
        })}
      </div>

      <p className="text-xs text-gray-400">
        Atualizado em: {new Date(data.checkedAt).toLocaleString('pt-BR')}
        {' · '}
        <span className="italic">Esta página não atualiza automaticamente — recarregue para ver o estado atual.</span>
      </p>
    </main>
  )
}
