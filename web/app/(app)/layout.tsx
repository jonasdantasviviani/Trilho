'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'
import { LogoLockup } from '@/components/ui/Logo'
import Link from 'next/link'

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())
  return (
    <QueryClientProvider client={queryClient}>
      <div className="flex h-screen bg-bg overflow-hidden">
        {/* ── Sidebar ─────────────────────────────────────────────────── */}
        <aside className="hidden md:flex flex-col w-60 border-r border-border bg-surface shrink-0">
          <div className="p-4 border-b border-border">
            <LogoLockup />
          </div>
          <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
            <Link
              href="/app"
              className="flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-text-secondary hover:bg-surface-raised hover:text-text-primary transition-colors"
            >
              Mapa
            </Link>
            <Link
              href="/app/settings"
              className="flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-text-secondary hover:bg-surface-raised hover:text-text-primary transition-colors"
            >
              Configurações
            </Link>
          </nav>
        </aside>

        {/* ── Main content ─────────────────────────────────────────────── */}
        <main className="flex-1 overflow-hidden">{children}</main>
      </div>
    </QueryClientProvider>
  )
}
