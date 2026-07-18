'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Train } from 'lucide-react'

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const res = await fetch(process.env.NEXT_PUBLIC_API_URL + '/api/admin/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })

      if (res.ok) {
        const data = await res.json()
        localStorage.setItem('admin_token', data.token)
        router.push('/dashboard')
      } else {
        setError('Credenciais inválidas')
      }
    } catch {
      setError('Erro ao conectar com o servidor')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-container">
      <div className="login-box">
        <div className="login-logo">
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 16 }}>
            <Train size={48} color="#1E88E5" />
          </div>
          <h1>Trilho Admin</h1>
          <p>Acesse o painel administrativo</p>
        </div>

        <form onSubmit={handleLogin}>
          {error && (
            <div style={{ 
              padding: '12px', 
              background: '#FFEBEE', 
              color: '#C62828', 
              borderRadius: 8, 
              marginBottom: 20,
              fontSize: 14
            }}>
              {error}
            </div>
          )}

          <div className="form-group">
            <label className="form-label">Email</label>
            <input
              type="email"
              className="form-input"
              placeholder="admin@trilho.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Senha</label>
            <input
              type="password"
              className="form-input"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button type="submit" className="login-btn" disabled={loading}>
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>
      </div>
    </div>
  )
}
