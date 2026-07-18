import { getSession } from '@/lib/auth'
import { redirect } from 'next/navigation'

export default async function SettingsPage() {
  const session = await getSession()
  if (!session) redirect('/login')

  return (
    <main className="max-w-lg mx-auto px-4 py-8 space-y-6">
      <h1 className="text-2xl font-bold">Configurações</h1>

      <div className="rounded-2xl border p-4 space-y-2">
        <p className="text-sm text-gray-500">Conta</p>
        <p className="font-medium">{session.email ?? 'Usuário anônimo'}</p>
        <p className="text-sm">
          Plano:{' '}
          <span className={`font-semibold ${session.isPremium || session.isVip ? 'text-blue-600' : 'text-gray-600'}`}>
            {session.isVip ? 'VIP' : session.isPremium ? 'Premium' : 'Gratuito'}
          </span>
        </p>
      </div>

      <form action="/api/auth/logout" method="POST">
        <button
          type="submit"
          className="w-full rounded-xl border border-red-200 text-red-600 px-4 py-3 text-sm font-medium hover:bg-red-50 transition"
        >
          Sair
        </button>
      </form>
    </main>
  )
}
