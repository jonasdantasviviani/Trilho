import { Nav } from '@/components/Nav'
import { Footer } from '@/components/Footer'
import { LineStatusTicker } from '@/components/LineStatusTicker'
import { LogoLockup } from '@/components/ui/Logo'
import { Button } from '@/components/ui/Button'
import { apiClient } from '@/lib/api'
import Link from 'next/link'

export const revalidate = 60

interface LineDto {
  code: string; name: string; currentStatus: string; statusMessage: string | null
}

async function getLines(): Promise<LineDto[]> {
  try { return await apiClient<LineDto[]>('/api/lines') }
  catch { return [] }
}

const features = [
  { icon: '⬡', title: 'Lotação ao vivo', desc: 'Veja em tempo real se o vagão está cheio antes de embarcar.' },
  { icon: '🕐', title: 'Próximo trem',    desc: 'Estimativa de chegada linha a linha, atualizada a cada 30s.' },
  { icon: '🔔', title: 'Alertas',          desc: 'Notificações push quando a lotação muda ou há interrupções.' },
]

export default async function HomePage() {
  const lines = await getLines()

  return (
    <>
      <Nav />

      {/* ── HERO ──────────────────────────────────────────────────────── */}
      <section className="relative min-h-screen flex flex-col items-center justify-center pt-20 px-6 text-center overflow-hidden">
        {/* Animated schematic map background — spec §4.1 */}
        <svg
          className="absolute inset-0 w-full h-full pointer-events-none opacity-20"
          viewBox="0 0 800 600"
          fill="none"
          aria-hidden="true"
        >
          {/* Horizontal lines pulsing */}
          <line className="hero-line" x1="0" y1="200" x2="800" y2="200" stroke="var(--color-accent)" strokeWidth="2"/>
          <line className="hero-line" x1="0" y1="300" x2="800" y2="300" stroke="var(--color-primary)" strokeWidth="2"/>
          <line className="hero-line" x1="0" y1="400" x2="800" y2="400" stroke="var(--color-accent)" strokeWidth="2"/>
          {/* Diagonal connector */}
          <line className="hero-line" x1="200" y1="200" x2="400" y2="300" stroke="var(--color-primary)" strokeWidth="1.5"/>
          <line className="hero-line" x1="400" y1="300" x2="600" y2="200" stroke="var(--color-primary)" strokeWidth="1.5"/>
          {/* Station nodes */}
          <circle className="hero-node" cx="200" cy="200" r="5" fill="var(--color-accent)"/>
          <circle className="hero-node" cx="400" cy="200" r="5" fill="var(--color-accent)"/>
          <circle className="hero-node" cx="600" cy="200" r="5" fill="var(--color-accent)"/>
          <circle className="hero-node" cx="300" cy="300" r="5" fill="var(--color-primary)"/>
          <circle className="hero-node" cx="500" cy="300" r="5" fill="var(--color-primary)"/>
          <circle className="hero-node" cx="200" cy="400" r="5" fill="var(--color-accent)"/>
          <circle className="hero-node" cx="600" cy="400" r="5" fill="var(--color-accent)"/>
        </svg>

        {/* Radial glow overlay */}
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(0,85,255,0.08)_0%,transparent_65%)] pointer-events-none" />

        <LogoLockup className="mb-8 relative" />

        <h1 className="text-4xl md:text-6xl font-extrabold tracking-tight text-text-primary text-balance max-w-3xl relative">
          Mobilidade em tempo real.
        </h1>
        <p className="mt-4 text-lg text-text-secondary max-w-xl relative">
          Saiba antes de sair de casa se o metrô está lotado.
        </p>

        <div className="mt-8 flex flex-wrap gap-3 justify-center relative">
          <a href="https://apps.apple.com">
            <Button size="lg">Baixar iOS</Button>
          </a>
          <a href="https://play.google.com">
            <Button variant="ghost" size="lg">Baixar Android</Button>
          </a>
          <Link href="/login">
            <Button variant="outline" size="lg">Abrir na web</Button>
          </Link>
        </div>
      </section>

      {/* ── STATUS TICKER ─────────────────────────────────────────────── */}
      <section className="bg-surface border-y border-border py-4 px-6">
        <LineStatusTicker lines={lines} />
      </section>

      {/* ── FEATURES ──────────────────────────────────────────────────── */}
      <section id="features" className="max-w-5xl mx-auto px-6 py-24">
        <h2 className="text-2xl font-bold text-center text-text-primary mb-12">
          Funcionalidades
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {features.map((f) => (
            <div key={f.title} className="bg-surface border border-border rounded-2xl p-6 space-y-3">
              <span className="text-3xl">{f.icon}</span>
              <h3 className="font-bold text-text-primary">{f.title}</h3>
              <p className="text-sm text-text-secondary">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── MAPA PREVIEW ──────────────────────────────────────────────── */}
      {/* spec §4.1: "Screenshot estático do mapa de São Paulo em dark mode" */}
      <section className="max-w-5xl mx-auto px-6 pb-16 text-center">
        <h2 className="text-2xl font-bold text-text-primary mb-4">
          Veja todas as linhas num relance
        </h2>
        <p className="text-text-secondary text-sm mb-8">
          Mapa esquemático interativo de SP — metrô e CPTM
        </p>
        {/* Placeholder map preview — replace with real screenshot at /images/map-preview.png */}
        <div className="relative mx-auto max-w-3xl rounded-2xl overflow-hidden border border-border bg-surface aspect-video flex items-center justify-center">
          <div className="text-text-disabled text-sm">
            {/* Replace with: <Image src="/images/map-preview.png" alt="Mapa esquemático do metrô de São Paulo" fill className="object-cover" /> */}
            Mapa preview — adicionar screenshot em /public/images/map-preview.png
          </div>
        </div>
      </section>

      {/* ── PRICING ───────────────────────────────────────────────────── */}
      <section id="pricing" className="max-w-3xl mx-auto px-6 pb-24">
        <h2 className="text-2xl font-bold text-center text-text-primary mb-12">Preços</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Free */}
          <div className="bg-surface border border-border rounded-2xl p-6 space-y-4">
            <h3 className="font-bold text-lg text-text-primary">Gratuito</h3>
            <p className="text-3xl font-extrabold text-text-primary">R$ 0</p>
            <ul className="text-sm text-text-secondary space-y-2">
              <li>✓ Lotação ao vivo</li>
              <li>✓ Mapa esquemático</li>
              <li>✓ Alertas básicos</li>
            </ul>
            <a href="https://apps.apple.com">
              <Button variant="ghost" fullWidth>Baixar grátis</Button>
            </a>
          </div>
          {/* Premium */}
          <div className="bg-surface border-2 border-accent rounded-2xl p-6 space-y-4 shadow-glow-accent">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-lg text-text-primary">Premium</h3>
              <span className="text-[10px] font-bold bg-accent/10 text-accent px-2 py-0.5 rounded-full">Mais popular</span>
            </div>
            <p className="text-3xl font-extrabold text-text-primary">
              R$ 9,90<span className="text-base font-normal text-text-secondary">/mês</span>
            </p>
            <ul className="text-sm text-text-secondary space-y-2">
              <li>✓ Tudo do gratuito</li>
              <li className="text-text-primary">✓ Estimativa de chegada</li>
              <li className="text-text-primary">✓ Notificações push</li>
              <li className="text-text-primary">✓ Acesso web completo</li>
            </ul>
            <Link href="/login">
              <Button fullWidth>Assinar agora</Button>
            </Link>
          </div>
        </div>
      </section>

      <Footer />
    </>
  )
}
