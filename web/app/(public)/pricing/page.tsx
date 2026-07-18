import Link from 'next/link'

export default function PricingPage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-4 py-16">
      <div className="max-w-2xl w-full space-y-8 text-center">
        <h1 className="text-3xl font-bold">Planos Trilho</h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-2xl border p-6 space-y-4">
            <h2 className="text-xl font-semibold">Gratuito</h2>
            <p className="text-3xl font-bold">R$ 0</p>
            <ul className="text-sm text-text-secondary space-y-2 text-left">
              <li>✓ 5 consultas por sessão</li>
              <li>✓ Status das linhas</li>
              <li>✗ Mapa em tempo real</li>
              <li>✗ Histórico de lotação</li>
            </ul>
            <Link href="/login" className="block rounded-xl border border-border px-4 py-2 text-sm font-medium hover:bg-surface-raised text-center">
              Começar grátis
            </Link>
          </div>

          <div className="rounded-2xl border-2 border-accent p-6 space-y-4">
            <h2 className="text-xl font-semibold">Premium</h2>
            <p className="text-3xl font-bold">R$ 9,90<span className="text-base font-normal text-text-secondary">/mês</span></p>
            <ul className="text-sm text-text-secondary space-y-2 text-left">
              <li>✓ Consultas ilimitadas</li>
              <li>✓ Mapa em tempo real</li>
              <li>✓ Histórico de lotação</li>
              <li>✓ Sem anúncios</li>
            </ul>
            <a href="trilho://paywall" className="block rounded-xl bg-primary text-white px-4 py-2 text-sm font-medium hover:opacity-90 text-center">
              Assinar no app
            </a>
          </div>
        </div>
      </div>
    </main>
  )
}
