'use client'

import { useState } from 'react'
import { Search, ChevronLeft, ChevronRight, UserPlus, Crown, Ban } from 'lucide-react'

const mockUsers = [
  { id: 1, email: 'joao@email.com', createdAt: '2026-03-15', isPremium: true, isVip: false, queriesToday: 12 },
  { id: 2, email: 'maria@email.com', createdAt: '2026-03-14', isPremium: false, isVip: false, queriesToday: 3 },
  { id: 3, email: 'carlos@email.com', createdAt: '2026-03-12', isPremium: true, isVip: true, queriesToday: 45 },
  { id: 4, email: 'ana@email.com', createdAt: '2026-03-10', isPremium: false, isVip: false, queriesToday: 5 },
  { id: 5, email: 'pedro@email.com', createdAt: '2026-03-08', isPremium: true, isVip: false, queriesToday: 8 },
  { id: 6, email: 'julia@email.com', createdAt: '2026-03-05', isPremium: false, isVip: false, queriesToday: 2 },
  { id: 7, email: 'fernando@email.com', createdAt: '2026-03-01', isPremium: true, isVip: false, queriesToday: 15 },
  { id: 8, email: 'sofia@email.com', createdAt: '2026-02-28', isPremium: false, isVip: true, queriesToday: 32 },
]

export default function UsersPage() {
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [filter, setFilter] = useState<'all' | 'premium' | 'free'>('all')
  const [users, setUsers] = useState(mockUsers)

  const filteredUsers = users.filter(user => {
    const matchesSearch = user.email.toLowerCase().includes(search.toLowerCase())
    const matchesFilter = filter === 'all' || 
      (filter === 'premium' && user.isPremium) ||
      (filter === 'free' && !user.isPremium)
    return matchesSearch && matchesFilter
  })

  const toggleVip = (id: number) => {
    setUsers(users.map(u => u.id === id ? { ...u, isVip: !u.isVip } : u))
  }

  return (
    <div>
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h1 className="page-title">Usuários</h1>
          <p className="page-subtitle">{users.length.toLocaleString('pt-BR')} usuários cadastrados</p>
        </div>
        <button className="btn btn-primary">
          <UserPlus size={18} />
          Exportar CSV
        </button>
      </div>

      <div className="card">
        <div style={{ display: 'flex', gap: 16, marginBottom: 24 }}>
          <div style={{ flex: 1, position: 'relative' }}>
            <Search size={18} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }} />
            <input
              type="text"
              className="form-input"
              placeholder="Buscar por email..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ paddingLeft: 40 }}
            />
          </div>
          <select 
            className="form-input" 
            style={{ width: 160 }}
            value={filter}
            onChange={(e) => setFilter(e.target.value as any)}
          >
            <option value="all">Todos</option>
            <option value="premium">Premium</option>
            <option value="free">Gratuitos</option>
          </select>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th>Email</th>
              <th>Data de Registro</th>
              <th>Plano</th>
              <th>VIP</th>
              <th>Consultas Hoje</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            {filteredUsers.map(user => (
              <tr key={user.id}>
                <td><strong>{user.email}</strong></td>
                <td>{new Date(user.createdAt).toLocaleDateString('pt-BR')}</td>
                <td>
                  {user.isPremium ? (
                    <span className="badge badge-success">Premium</span>
                  ) : (
                    <span className="badge badge-warning">Gratuito</span>
                  )}
                </td>
                <td>
                  {user.isVip && <Crown size={16} color="#FFD700" />}
                </td>
                <td>{user.queriesToday}</td>
                <td>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button 
                      onClick={() => toggleVip(user.id)}
                      className="btn"
                      style={{ padding: '6px 12px', fontSize: 13 }}
                      title={user.isVip ? 'Remover VIP' : 'Tornar VIP'}
                    >
                      <Crown size={14} />
                    </button>
                    <button 
                      className="btn"
                      style={{ padding: '6px 12px', fontSize: 13, color: 'var(--error)' }}
                      title="Bloquear usuário"
                    >
                      <Ban size={14} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 24 }}>
          <span style={{ color: 'var(--text-secondary)', fontSize: 14 }}>
            Mostrando {filteredUsers.length} de {users.length} usuários
          </span>
          <div style={{ display: 'flex', gap: 8 }}>
            <button 
              className="btn" 
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              style={{ opacity: page === 1 ? 0.5 : 1 }}
            >
              <ChevronLeft size={18} />
            </button>
            <span style={{ padding: '8px 16px' }}>Página {page}</span>
            <button 
              className="btn" 
              onClick={() => setPage(p => p + 1)}
              disabled={filteredUsers.length < 10}
              style={{ opacity: filteredUsers.length < 10 ? 0.5 : 1 }}
            >
              <ChevronRight size={18} />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
