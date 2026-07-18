'use client'

import { useState } from 'react'
import { 
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'

const COLORS = ['#1E88E5', '#26A69A', '#FFC107', '#F44336', '#9C27B0', '#FF9800']

const weeklyData = [
  { day: 'Seg', queries: 45000, users: 2100 },
  { day: 'Ter', queries: 52000, users: 2400 },
  { day: 'Qua', queries: 48000, users: 2250 },
  { day: 'Qui', queries: 61000, users: 2800 },
  { day: 'Sex', queries: 73000, users: 3200 },
  { day: 'Sáb', queries: 35000, users: 1800 },
  { day: 'Dom', queries: 28000, users: 1500 },
]

const monthlyData = [
  { month: 'Set', queries: 1.2, premium: 850 },
  { month: 'Out', queries: 1.5, premium: 920 },
  { month: 'Nov', queries: 1.8, premium: 1100 },
  { month: 'Dez', queries: 1.4, premium: 980 },
  { month: 'Jan', queries: 1.9, premium: 1250 },
  { month: 'Fev', queries: 2.1, premium: 1420 },
]

const deviceData = [
  { name: 'Android', value: 62 },
  { name: 'iOS', value: 31 },
  { name: 'Web', value: 7 },
]

const revenueData = [
  { month: 'Set', mrr: 8500 },
  { month: 'Out', mrr: 9200 },
  { month: 'Nov', mrr: 11000 },
  { month: 'Dez', mrr: 9800 },
  { month: 'Jan', mrr: 12500 },
  { month: 'Fev', mrr: 14200 },
]

export default function AnalyticsPage() {
  const [period, setPeriod] = useState<'week' | 'month' | 'year'>('month')

  return (
    <div>
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h1 className="page-title">Analytics</h1>
          <p className="page-subtitle">Métricas de uso e receita</p>
        </div>
        <div style={{ display: 'flex', gap: 12 }}>
          {(['week', 'month', 'year'] as const).map(p => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className="btn"
              style={{
                background: period === p ? 'var(--primary)' : 'var(--surface)',
                color: period === p ? 'white' : 'var(--text-primary)',
                border: '1px solid var(--border)',
                textTransform: 'capitalize'
              }}
            >
              {p === 'week' ? 'Semana' : p === 'month' ? 'Mês' : 'Ano'}
            </button>
          ))}
        </div>
      </div>

      <div className="stats-grid" style={{ gridTemplateColumns: 'repeat(4, 1fr)' }}>
        <div className="stat-card">
          <div className="stat-label">Receita MRR</div>
          <div className="stat-value">R$ 14.200</div>
          <div className="stat-change up">+18% vs mês anterior</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Usuários Premium</div>
          <div className="stat-value">1.420</div>
          <div className="stat-change up">+12% este mês</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Taxa Conversão</div>
          <div className="stat-value">3.2%</div>
          <div className="stat-change up">+0.4% este mês</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Churn Rate</div>
          <div className="stat-value">2.1%</div>
          <div className="stat-change down">-0.3% este mês</div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 24, marginBottom: 24 }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Receita Mensal (R$)</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={revenueData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
                <XAxis dataKey="month" stroke="#757575" fontSize={12} />
                <YAxis stroke="#757575" fontSize={12} tickFormatter={(v) => `R$ ${v}`} />
                <Tooltip formatter={(value: any) => [`R$ ${value.toLocaleString('pt-BR')}`, 'MRR']} />
                <Line 
                  type="monotone" 
                  dataKey="mrr" 
                  stroke="#1E88E5" 
                  strokeWidth={3}
                  dot={{ fill: '#1E88E5', strokeWidth: 2 }}
                  activeDot={{ r: 6 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Dispositivos</h3>
          </div>
          <div style={{ height: 200 }}>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={deviceData}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={80}
                  paddingAngle={2}
                  dataKey="value"
                >
                  {deviceData.map((_, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 16, marginTop: 16 }}>
            {deviceData.map((d, i) => (
              <div key={d.name} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 10, height: 10, borderRadius: 2, background: COLORS[i] }} />
                <span style={{ fontSize: 13 }}>{d.name} {d.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Consultas por Dia da Semana</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={weeklyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
                <XAxis dataKey="day" stroke="#757575" fontSize={12} />
                <YAxis stroke="#757575" fontSize={12} />
                <Tooltip />
                <Bar dataKey="queries" fill="#1E88E5" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Usuários Únicos (milhares)</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={monthlyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
                <XAxis dataKey="month" stroke="#757575" fontSize={12} />
                <YAxis stroke="#757575" fontSize={12} />
                <Tooltip />
                <Legend />
                <Line 
                  type="monotone" 
                  dataKey="users" 
                  stroke="#26A69A" 
                  strokeWidth={2}
                  name="Usuários"
                />
                <Line 
                  type="monotone" 
                  dataKey="premium" 
                  stroke="#FFC107" 
                  strokeWidth={2}
                  name="Premium"
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}
