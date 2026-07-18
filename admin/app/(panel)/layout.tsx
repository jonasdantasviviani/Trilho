import Link from 'next/link'
import { signOut } from '@/auth'

export default function PanelLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <aside className="w-48 border-r bg-gray-50 flex flex-col">
        <div className="p-4 border-b font-bold text-gray-800">Trilho Admin</div>
        <nav className="flex-1 p-3 space-y-1">
          {[
            { href: '/', label: 'Visão Geral' },
            { href: '/users', label: 'Usuários' },
            { href: '/financial', label: 'Financeiro' },
            { href: '/operational', label: 'Operacional' },
            { href: '/health', label: '🟢 Saúde Dados' },
          ].map(item => (
            <Link key={item.href} href={item.href}
              className="block rounded-lg px-3 py-2 text-sm text-gray-700 hover:bg-gray-200 transition">
              {item.label}
            </Link>
          ))}
        </nav>
        <form action={async () => { 'use server'; await signOut({ redirectTo: '/login' }) }} className="p-3">
          <button type="submit" className="w-full text-sm text-gray-500 hover:text-red-600 text-left px-3 py-2">
            Sair
          </button>
        </form>
      </aside>
      <div className="flex-1 overflow-auto">{children}</div>
    </div>
  )
}
