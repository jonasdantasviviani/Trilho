'use client'

import { useEffect, useState } from 'react'
import { Users, Train, Activity, TrendingUp, Clock, AlertTriangle } from 'lucide-react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts'

const mockStats = {
  totalUsers: 12847,
  activeUsers: 3421,
  queriesToday: 89432,
  errorRate: 0.02,
}

const mockQueriesData = [
  { time: '00:00', count: 1200 },
  { time: '04:00', count: 800 },
  { time: '08:00', count: 15200 },
  { time: '12:00', count: 18500 },
  { time: '16:00', count: 22100 },
  { time: '20:00', count: 14600 },
  { time: '23:00', count: 9800 },
]

const mockTopStations = [
  { name: 'Sé', line: '1-AZUL', queries: 4521 },
  { name: 'Paulista', line: '1-AZUL', queries: 3892 },
  { name: 'Trianon-Masp', line: '4-AMARELA', queries: 3541 },
  { name: 'Consolação', line: '2-VERDE', queries: 3128 },
  { name: 'Luz', line: '1-AZUL', queries: 2987 },
]

const mockLines = [
  { code: '1-AZUL', name: 'Linha 1 - Azul', status: 'normal', density: 68 },
  { code: '2-VERDE', name: 'Linha 2 - Verde', status: 'normal', density: 54 },
  { code: '3-VERMELHA', name: 'Linha 3 - Vermelha', status: 'reduced', density: 82 },
  { code: '4-AMARELA', name: 'Linha 4 - Amarela', status: 'normal', density: 71 },
  { code: '7-RUBI', name: 'Linha 7 - Rubi', status: 'alert', density: 45 },
]

export default function DashboardPage() {
  const [stats, setStats] = useState(mockStats)

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Dashboard</h1>
        <p className="page-subtitle">Visão geral do sistema</p>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-label">
            <Users size={16} style={{ marginRight: 8, opacity: 0.7 }} />
            Total de Usuários
          </div>
          <div className="stat-value">{stats.totalUsers.toLocaleString('pt-BR')}</div>
          <div className="stat-change up">
            <TrendingUp size={14} style={{ marginRight: 4 }} />
            +12% este mês
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-label">
            <Activity size={16} style={{ marginRight: 8, opacity: 0.7 }} />
            Usuários Ativos
          </div>
          <div className="stat-value">{stats.activeUsers.toLocaleString('pt-BR')}</div>
          <div className="stat-change up">
            <TrendingUp size={14} style={{ marginRight: 4 }} />
            +8% esta semana
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-label">
            <Clock size={16} style={{ marginRight: 8, opacity: 0.7 }} />
            Consultas Hoje
          </div>
          <div className="stat-value">{stats.queriesToday.toLocaleString('pt-BR')}</div>
          <div className="stat-change up">
            <TrendingUp size={14} style={{ marginRight: 4 }} />
            +23% vs ontem
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-label">
            <AlertTriangle size={16} style={{ marginRight: 8, opacity: 0.7 }} />
            Taxa de Erro
          </div>
          <div className="stat-value">{(stats.errorRate * 100).toFixed(2)}%</div>
          <div className="stat-change down">
            -0.01% vs média
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 24 }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Consultas por Hora (Hoje)</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={mockQueriesData}>
                <defs>
                  <linearGradient id="colorCount" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#1E88E5" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#1E88E5" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
                <XAxis dataKey="time" stroke="#757575" fontSize={12} />
                <YAxis stroke="#757575" fontSize={12} />
                <Tooltip />
                <Area 
                  type="monotone" 
                  dataKey="count" 
                  stroke="#1E88E5" 
                  fillOpacity={1} 
                  fill="url(#colorCount)" 
                  strokeWidth={2}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Linhas com Problemas</h3>
          </div>
          <div className="line-status-list">
            {mockLines.filter(l => l.status !== 'normal').map(line => (
              <div key={line.code} className="line-status-item">
                <div className="line-color" style={{ background: `#${line.code.split('-')[1] === 'AZUL' ? '0044AA' : line.code.split('-')[1] === 'VERDE' ? '007A4D' : 'EE1C25'}` }}>
                  {line.code.split('-')[0]}
                </div>
                <div className="line-info">
                  <div className="line-name">{line.name}</div>
                  <div className="line-status">
                    <span className={`status-dot status-${line.status}`}></span>
                    {line.status === 'reduced' ? 'Velocidade reduzida' : 'Operação parcial'}
                  </div>
                </div>
              </div>
            ))}
            {mockLines.filter(l => l.status !== 'normal').length === 0 && (
              <p style={{ color: 'var(--text-secondary)', textAlign: 'center', padding: 20 }}>
                Nenhuma linha com problemas
              </p>
            )}
          </div>
        </div>
      </div>

      <div className="card" style={{ marginTop: 24 }}>
        <div className="card-header">
          <h3 className="card-title">Estações Mais Consultadas</h3>
        </div>
        <table className="data-table">
          <thead>
            <tr>
              <th>Estação</th>
              <th>Linha</th>
              <th>Consultas Hoje</th>
              <th>Tendência</th>
            </tr>
          </thead>
          <tbody>
            {mockTopStations.map((station, i) => (
              <tr key={station.name}>
                <td><strong>{station.name}</strong></td>
                <td>
                  <span className="badge badge-info">{station.line}</span>
                </td>
                <td>{station.queries.toLocaleString('pt-BR')}</td>
                <td>
                  <span className="stat-change up" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <TrendingUp size={14} /> +{Math.floor(Math.random() * 15 + 5)}%
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
