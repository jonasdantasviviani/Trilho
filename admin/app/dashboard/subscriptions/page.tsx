'use client'

import { useState } from 'react'
import { Search, CreditCard, X, RefreshCw, Clock, Check, AlertTriangle, Download } from 'lucide-react'

const mockSubscriptions = [
  { 
    id: 'sub_001', 
    userId: 'usr_001',
    userEmail: 'joao@email.com',
    plan: 'monthly',
    planName: 'Premium Mensal',
    price: 990,
    status: 'active',
    startDate: '2026-02-15',
    nextBilling: '2026-03-15',
    paymentMethod: 'PIX',
    cancelledAt: null
  },
  { 
    id: 'sub_002', 
    userId: 'usr_002',
    userEmail: 'maria@email.com',
    plan: 'monthly',
    planName: 'Premium Mensal',
    price: 990,
    status: 'active',
    startDate: '2026-03-01',
    nextBilling: '2026-04-01',
    paymentMethod: 'CARD',
    cancelledAt: null
  },
  { 
    id: 'sub_003', 
    userId: 'usr_003',
    userEmail: 'carlos@email.com',
    plan: 'quarterly',
    planName: 'Premium Trimestral',
    price: 2490,
    status: 'cancelled',
    startDate: '2025-12-01',
    nextBilling: null,
    paymentMethod: 'PIX',
    cancelledAt: '2026-03-01'
  },
  { 
    id: 'sub_004', 
    userId: 'usr_004',
    userEmail: 'ana@email.com',
    plan: 'annual',
    planName: 'Premium Anual',
    price: 9900,
    status: 'active',
    startDate: '2026-01-10',
    nextBilling: '2027-01-10',
    paymentMethod: 'PIX',
    cancelledAt: null
  },
  { 
    id: 'sub_005', 
    userId: 'usr_005',
    userEmail: 'pedro@email.com',
    plan: 'monthly',
    planName: 'Premium Mensal',
    price: 990,
    status: 'past_due',
    startDate: '2026-02-20',
    nextBilling: '2026-03-20',
    paymentMethod: 'CARD',
    cancelledAt: null
  },
]

const stats = {
  totalActive: 1247,
  totalCancelled: 89,
  mrr: 1234530,
  churnRate: 7.1,
  avgRevenue: 9.90,
}

export default function SubscriptionsPage() {
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'cancelled' | 'past_due'>('all')
  const [subscriptions, setSubscriptions] = useState(mockSubscriptions)
  const [showCancelModal, setShowCancelModal] = useState<string | null>(null)
  const [showChangePlanModal, setShowChangePlanModal] = useState<string | null>(null)

  const filteredSubscriptions = subscriptions.filter(sub => {
    const matchesSearch = sub.userEmail.toLowerCase().includes(search.toLowerCase())
    const matchesFilter = statusFilter === 'all' || sub.status === statusFilter
    return matchesSearch && matchesFilter
  })

  const formatPrice = (cents: number) => {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(cents / 100)
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'active':
        return <span className="badge badge-success">Ativa</span>
      case 'cancelled':
        return <span className="badge badge-error">Cancelada</span>
      case 'past_due':
        return <span className="badge badge-warning">Atrasada</span>
      default:
        return <span className="badge">{status}</span>
    }
  }

  const handleCancel = (id: string) => {
    setSubscriptions(subscriptions.map(s => 
      s.id === id 
        ? { ...s, status: 'cancelled', cancelledAt: new Date().toISOString().split('T')[0], nextBilling: null }
        : s
    ))
    setShowCancelModal(null)
  }

  const handleReactivate = (id: string) => {
    setSubscriptions(subscriptions.map(s => 
      s.id === id 
        ? { ...s, status: 'active', cancelledAt: null, nextBilling: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0] }
        : s
    ))
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Assinaturas</h1>
          <p className="page-subtitle">Gerencie assinaturas e pagamentos</p>
        </div>
        <button className="btn btn-primary">
          <Download size={18} />
          Exportar Relatório
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <div className="card stat-card">
          <div className="stat-label">Assinaturas Ativas</div>
          <div className="stat-value">{stats.totalActive.toLocaleString('pt-BR')}</div>
        </div>
        <div className="card stat-card">
          <div className="stat-label">Canceladas</div>
          <div className="stat-value" style={{ color: 'var(--error)' }}>{stats.totalCancelled}</div>
        </div>
        <div className="card stat-card">
          <div className="stat-label">MRR (Receita Mensal)</div>
          <div className="stat-value">{formatPrice(stats.mrr)}</div>
        </div>
        <div className="card stat-card">
          <div className="stat-label">Taxa de Churn</div>
          <div className="stat-value">{stats.churnRate}%</div>
        </div>
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
            style={{ width: 180 }}
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
          >
            <option value="all">Todas</option>
            <option value="active">Ativas</option>
            <option value="cancelled">Canceladas</option>
            <option value="past_due">Atrasadas</option>
          </select>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th>Usuário</th>
              <th>Plano</th>
              <th>Valor</th>
              <th>Status</th>
              <th>Próxima Cobrança</th>
              <th>Método</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            {filteredSubscriptions.map(sub => (
              <tr key={sub.id}>
                <td><strong>{sub.userEmail}</strong></td>
                <td>{sub.planName}</td>
                <td>{formatPrice(sub.price)}</td>
                <td>{getStatusBadge(sub.status)}</td>
                <td>
                  {sub.nextBilling ? (
                    <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <Clock size={14} />
                      {new Date(sub.nextBilling).toLocaleDateString('pt-BR')}
                    </span>
                  ) : (
                    <span style={{ color: 'var(--text-secondary)' }}>-</span>
                  )}
                </td>
                <td>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                    <CreditCard size={14} />
                    {sub.paymentMethod}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 8 }}>
                    {sub.status === 'active' && (
                      <>
                        <button 
                          onClick={() => setShowChangePlanModal(sub.id)}
                          className="btn"
                          style={{ padding: '6px 12px', fontSize: 13 }}
                          title="Trocar plano"
                        >
                          <RefreshCw size={14} />
                        </button>
                        <button 
                          onClick={() => setShowCancelModal(sub.id)}
                          className="btn"
                          style={{ padding: '6px 12px', fontSize: 13, color: 'var(--error)' }}
                          title="Cancelar assinatura"
                        >
                          <X size={14} />
                        </button>
                      </>
                    )}
                    {sub.status === 'cancelled' && (
                      <button 
                        onClick={() => handleReactivate(sub.id)}
                        className="btn btn-primary"
                        style={{ padding: '6px 12px', fontSize: 13 }}
                      >
                        <RefreshCw size={14} />
                        Reativar
                      </button>
                    )}
                    {sub.status === 'past_due' && (
                      <button 
                        className="btn"
                        style={{ padding: '6px 12px', fontSize: 13, color: 'var(--warning)' }}
                        title="Enviar lembrete"
                      >
                        <AlertTriangle size={14} />
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showCancelModal && (
        <div className="modal-overlay" onClick={() => setShowCancelModal(null)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <h3 style={{ marginBottom: 16 }}>Cancelar Assinatura</h3>
            <p style={{ marginBottom: 24, color: 'var(--text-secondary)' }}>
              Tem certeza que deseja cancelar esta assinatura? O usuário ainda terá acesso até o fim do período pago.
            </p>
            <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
              <button className="btn" onClick={() => setShowCancelModal(null)}>
                Voltar
              </button>
              <button 
                className="btn btn-danger"
                onClick={() => handleCancel(showCancelModal)}
              >
                <X size={16} />
                Confirmar Cancelamento
              </button>
            </div>
          </div>
        </div>
      )}

      {showChangePlanModal && (
        <div className="modal-overlay" onClick={() => setShowChangePlanModal(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
            <h3 style={{ marginBottom: 16 }}>Trocar Plano</h3>
            <div style={{ display: 'grid', gap: 12, marginBottom: 24 }}>
              <label className="plan-option">
                <input type="radio" name="plan" value="monthly" defaultChecked />
                <div className="plan-content">
                  <span className="plan-name">Mensal</span>
                  <span className="plan-price">R$ 9,90/mês</span>
                </div>
              </label>
              <label className="plan-option">
                <input type="radio" name="plan" value="quarterly" />
                <div className="plan-content">
                  <span className="plan-name">Trimestral</span>
                  <span className="plan-price">R$ 24,90/trimestre</span>
                  <span className="plan-badge">Economia de 16%</span>
                </div>
              </label>
              <label className="plan-option">
                <input type="radio" name="plan" value="annual" />
                <div className="plan-content">
                  <span className="plan-name">Anual</span>
                  <span className="plan-price">R$ 99,00/ano</span>
                  <span className="plan-badge">Economia de 17%</span>
                </div>
              </label>
            </div>
            <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
              <button className="btn" onClick={() => setShowChangePlanModal(null)}>
                Cancelar
              </button>
              <button className="btn btn-primary">
                <Check size={16} />
                Confirmar Troca
              </button>
            </div>
          </div>
        </div>
      )}

      <style jsx>{`
        .stat-card {
          padding: 20px;
        }
        .stat-label {
          font-size: 13px;
          color: var(--text-secondary);
          margin-bottom: 8px;
        }
        .stat-value {
          font-size: 28px;
          font-weight: 600;
        }
        .badge-error {
          background: rgba(239, 68, 68, 0.1);
          color: var(--error);
          padding: 4px 10px;
          border-radius: 12px;
          font-size: 12px;
          font-weight: 500;
        }
        .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 1000;
        }
        .modal {
          background: var(--bg-card);
          border-radius: 12px;
          padding: 24px;
          max-width: 400px;
          width: 90%;
        }
        .plan-option {
          display: flex;
          align-items: center;
          padding: 16px;
          border: 1px solid var(--border);
          border-radius: 8px;
          cursor: pointer;
          transition: all 0.2s;
        }
        .plan-option:hover {
          border-color: var(--primary);
        }
        .plan-option input {
          margin-right: 12px;
        }
        .plan-content {
          display: flex;
          flex-direction: column;
          flex: 1;
        }
        .plan-name {
          font-weight: 500;
        }
        .plan-price {
          color: var(--text-secondary);
          font-size: 14px;
        }
        .plan-badge {
          background: var(--success);
          color: white;
          padding: 2px 8px;
          border-radius: 4px;
          font-size: 11px;
          width: fit-content;
          margin-top: 4px;
        }
        .btn-danger {
          background: var(--error);
          color: white;
        }
        .btn-danger:hover {
          background: #dc2626;
        }
      `}</style>
    </div>
  )
}
