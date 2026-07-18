'use client'

import { useState } from 'react'
import { Save, Key, Bell, Database, Globe } from 'lucide-react'

export default function SettingsPage() {
  const [apiToken, setApiToken] = useState('')
  const [notifications, setNotifications] = useState({
    alerts: true,
    reports: true,
    errors: true,
  })

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Configurações</h1>
        <p className="page-subtitle">Gerenciar configurações do sistema</p>
      </div>

      <div style={{ maxWidth: 800 }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Key size={20} />
              Credenciais API
            </h3>
          </div>
          <div className="form-group">
            <label className="form-label">Token OlhoVivo (SPTrans)</label>
            <input
              type="password"
              className="form-input"
              placeholder="Cole o token da API SPTrans"
              value={apiToken}
              onChange={(e) => setApiToken(e.target.value)}
            />
            <p style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
              O token deve ser obtido em sptrans.com.br/desenvolvedores
            </p>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Bell size={20} />
              Notificações
            </h3>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {[
              { key: 'alerts', label: 'Alertas de status das linhas', desc: 'Receba notificações quando houver mudanças no status operacional' },
              { key: 'reports', label: 'Relatórios diários', desc: 'Receba um resumo diário de uso e métricas' },
              { key: 'errors', label: 'Alertas de erro', desc: 'Notificações quando a taxa de erro ultrapassar 1%' },
            ].map(item => (
              <label key={item.key} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={notifications[item.key as keyof typeof notifications]}
                  onChange={(e) => setNotifications({ ...notifications, [item.key]: e.target.checked })}
                  style={{ marginTop: 4, width: 18, height: 18 }}
                />
                <div>
                  <div style={{ fontWeight: 500 }}>{item.label}</div>
                  <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{item.desc}</div>
                </div>
              </label>
            ))}
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Globe size={20} />
              Cidades Ativas
            </h3>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th>Cidade</th>
                <th>Estado</th>
                <th>Status</th>
                <th>Estações</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>São Paulo</strong></td>
                <td>SP</td>
                <td><span className="badge badge-success">Ativa</span></td>
                <td>13 linhas</td>
              </tr>
              <tr>
                <td><strong>Rio de Janeiro</strong></td>
                <td>RJ</td>
                <td><span className="badge badge-warning">Pendente</span></td>
                <td>—</td>
              </tr>
              <tr>
                <td><strong>Belo Horizonte</strong></td>
                <td>MG</td>
                <td><span className="badge badge-warning">Pendente</span></td>
                <td>—</td>
              </tr>
              <tr>
                <td><strong>Curitiba</strong></td>
                <td>PR</td>
                <td><span className="badge badge-warning">Pendente</span></td>
                <td>—</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Database size={20} />
              Dados do Sistema
            </h3>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
            <div style={{ padding: 16, background: 'var(--background)', borderRadius: 8 }}>
              <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>Usuários</div>
              <div style={{ fontSize: 24, fontWeight: 700 }}>12.847</div>
            </div>
            <div style={{ padding: 16, background: 'var(--background)', borderRadius: 8 }}>
              <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>Pings Hoje</div>
              <div style={{ fontSize: 24, fontWeight: 700 }}>45.231</div>
            </div>
            <div style={{ padding: 16, background: 'var(--background)', borderRadius: 8 }}>
              <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>Último Import GTFS</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>22/03/2026</div>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 24 }}>
          <button className="btn" style={{ border: '1px solid var(--border)' }}>
            Cancelar
          </button>
          <button className="btn btn-primary">
            <Save size={18} />
            Salvar Alterações
          </button>
        </div>
      </div>
    </div>
  )
}
