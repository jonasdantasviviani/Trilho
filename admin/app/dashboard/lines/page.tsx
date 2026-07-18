'use client'

import { useState } from 'react'
import { RefreshCw, AlertTriangle, CheckCircle, Clock } from 'lucide-react'

const lineColors: Record<string, string> = {
  '1-AZUL': '#0044AA',
  '2-VERDE': '#007A4D',
  '3-VERMELHA': '#EE1C25',
  '4-AMARELA': '#FFD400',
  '5-LILAS': '#9B2990',
  '7-RUBI': '#EE1C25',
  '8-DIAMANTE': '#9E9E9E',
  '9-ESMERALDA': '#007A4D',
  '10-TURQUESA': '#008080',
  '11-CORAL': '#F7941D',
  '12-SAFIRA': '#003DA5',
  '13-JADE': '#00A859',
  '15-PRATA': '#9E9E9E',
}

const mockLines = [
  { code: '1-AZUL', name: 'Linha 1 - Azul', type: 'Metro', status: 'Normal', lastUpdate: '2 min', avgDensity: 68, stations: 23 },
  { code: '2-VERDE', name: 'Linha 2 - Verde', type: 'Metro', status: 'Normal', lastUpdate: '1 min', avgDensity: 54, stations: 14 },
  { code: '3-VERMELHA', name: 'Linha 3 - Vermelha', type: 'Metro', status: 'Velocidade Reduzida', lastUpdate: '5 min', avgDensity: 82, stations: 18 },
  { code: '4-AMARELA', name: 'Linha 4 - Amarela', type: 'Metro', status: 'Normal', lastUpdate: '2 min', avgDensity: 71, stations: 11 },
  { code: '5-LILAS', name: 'Linha 5 - Lilás', type: 'Metro', status: 'Normal', lastUpdate: '3 min', avgDensity: 45, stations: 17 },
  { code: '7-RUBI', name: 'Linha 7 - Rubi', type: 'CPTM', status: 'Operação Parcial', lastUpdate: '8 min', avgDensity: 45, stations: 20 },
  { code: '8-DIAMANTE', name: 'Linha 8 - Diamante', type: 'CPTM', status: 'Normal', lastUpdate: '2 min', avgDensity: 38, stations: 13 },
  { code: '9-ESMERALDA', name: 'Linha 9 - Esmeralda', type: 'CPTM', status: 'Normal', lastUpdate: '1 min', avgDensity: 62, stations: 18 },
  { code: '10-TURQUESA', name: 'Linha 10 - Turquesa', type: 'CPTM', status: 'Normal', lastUpdate: '2 min', avgDensity: 35, stations: 8 },
  { code: '11-CORAL', name: 'Linha 11 - Coral', type: 'CPTM', status: 'Normal', lastUpdate: '1 min', avgDensity: 58, stations: 11 },
  { code: '12-SAFIRA', name: 'Linha 12 - Safira', type: 'CPTM', status: 'Normal', lastUpdate: '3 min', avgDensity: 28, stations: 10 },
  { code: '13-JADE', name: 'Linha 13 - Jade', type: 'CPTM', status: 'Normal', lastUpdate: '2 min', avgDensity: 22, stations: 3 },
  { code: '15-PRATA', name: 'Linha 15 - Prata', type: 'Metro', status: 'Normal', lastUpdate: '1 min', avgDensity: 31, stations: 6 },
]

const statusConfig: Record<string, { icon: any, color: string, badge: string }> = {
  'Normal': { icon: CheckCircle, color: 'var(--success)', badge: 'badge-success' },
  'Velocidade Reduzida': { icon: Clock, color: 'var(--warning)', badge: 'badge-warning' },
  'Operação Parcial': { icon: AlertTriangle, color: 'var(--error)', badge: 'badge-error' },
}

export default function LinesPage() {
  const [filter, setFilter] = useState<'all' | 'metro' | 'cptm' | 'issues'>('all')
  const [lines, setLines] = useState(mockLines)

  const filteredLines = lines.filter(line => {
    if (filter === 'all') return true
    if (filter === 'metro') return line.type === 'Metro'
    if (filter === 'cptm') return line.type === 'CPTM'
    if (filter === 'issues') return line.status !== 'Normal'
    return true
  })

  const refreshLine = (code: string) => {
    setLines(lines.map(l => l.code === code ? { ...l, lastUpdate: 'agora' } : l))
  }

  return (
    <div>
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h1 className="page-title">Linhas</h1>
          <p className="page-subtitle">Status operacional em tempo real</p>
        </div>
        <button className="btn btn-primary">
          <RefreshCw size={18} />
          Atualizar Tudo
        </button>
      </div>

      <div style={{ display: 'flex', gap: 12, marginBottom: 24 }}>
        {[
          { value: 'all', label: 'Todas' },
          { value: 'metro', label: 'Metrô' },
          { value: 'cptm', label: 'CPTM' },
          { value: 'issues', label: 'Com Problemas' },
        ].map(f => (
          <button
            key={f.value}
            onClick={() => setFilter(f.value as any)}
            className="btn"
            style={{
              background: filter === f.value ? 'var(--primary)' : 'var(--surface)',
              color: filter === f.value ? 'white' : 'var(--text-primary)',
              border: '1px solid var(--border)',
            }}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Linha</th>
              <th>Tipo</th>
              <th>Status</th>
              <th>Lotenção Média</th>
              <th>Estações</th>
              <th>Última Atualização</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            {filteredLines.map(line => {
              const config = statusConfig[line.status]
              const StatusIcon = config.icon
              return (
                <tr key={line.code}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <div 
                        className="line-color" 
                        style={{ 
                          background: lineColors[line.code] || '#9E9E9E',
                          color: ['4-AMARELA'].includes(line.code) ? '#000' : '#FFF'
                        }}
                      >
                        {line.code.split('-')[0]}
                      </div>
                      <span style={{ fontWeight: 600 }}>{line.name}</span>
                    </div>
                  </td>
                  <td>
                    <span className="badge badge-info">{line.type}</span>
                  </td>
                  <td>
                    <span className={`badge ${config.badge}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                      <StatusIcon size={14} />
                      {line.status}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{ width: 100 }}>
                        <div className="usage-bar">
                          <div 
                            className="usage-bar-fill" 
                            style={{ 
                              width: `${line.avgDensity}%`,
                              background: line.avgDensity > 80 ? 'var(--error)' : 
                                         line.avgDensity > 50 ? 'var(--warning)' : 'var(--success)'
                            }}
                          />
                        </div>
                      </div>
                      <span style={{ fontSize: 13, minWidth: 35 }}>{line.avgDensity}%</span>
                    </div>
                  </td>
                  <td>{line.stations}</td>
                  <td>
                    <span style={{ color: 'var(--text-secondary)', fontSize: 13 }}>
                      {line.lastUpdate === 'agora' ? 'Atualizado agora' : `Há ${line.lastUpdate}`}
                    </span>
                  </td>
                  <td>
                    <button 
                      onClick={() => refreshLine(line.code)}
                      className="btn"
                      style={{ padding: '6px 12px', fontSize: 13 }}
                      title="Atualizar"
                    >
                      <RefreshCw size={14} />
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
