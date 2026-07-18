import { adminApiClient } from '@/lib/admin-api'
import { VipToggle } from '@/components/VipToggle'
import { QueryProvider } from '@/components/QueryProvider'

interface AdminUserDto {
  id: string; isPremium: boolean; isVip: boolean
  vipEmail: string | null; dailyQueriesUsed: number; createdAt: string
}
interface PageDto { items: AdminUserDto[]; total: number; page: number; size: number }

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; search?: string; filter?: string }>
}) {
  const sp = await searchParams
  const page = Number(sp.page ?? 1)
  const params = new URLSearchParams({ page: String(page), size: '20' })
  if (sp.search) params.set('search', sp.search)
  if (sp.filter) params.set('filter', sp.filter)

  let data: PageDto = { items: [], total: 0, page: 1, size: 20 }
  try { data = await adminApiClient<PageDto>(`/api/admin/users?${params}`) } catch {}

  return (
    <QueryProvider>
      <main className="p-6 space-y-4">
        <h1 className="text-2xl font-bold">Usuários</h1>
        <p className="text-sm text-gray-500">{data.total} usuários no total</p>
        <div className="overflow-x-auto rounded-2xl border">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                {['Email/ID', 'Premium', 'VIP', 'Consultas', 'Criado em'].map(h => (
                  <th key={h} className="px-4 py-3 text-left font-medium text-gray-600">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y">
              {data.items.map(u => (
                <tr key={u.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-500 font-mono text-xs">
                    {u.vipEmail ?? u.id.slice(0, 8) + '…'}
                  </td>
                  <td className="px-4 py-3">
                    {u.isPremium ? <span className="text-blue-600 font-medium">✓</span> : '—'}
                  </td>
                  <td className="px-4 py-3">
                    <VipToggle userId={u.id} initialIsVip={u.isVip} initialEmail={u.vipEmail} />
                  </td>
                  <td className="px-4 py-3">{u.dailyQueriesUsed}</td>
                  <td className="px-4 py-3 text-gray-500">
                    {new Date(u.createdAt).toLocaleDateString('pt-BR')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </QueryProvider>
  )
}
