'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  signInWithPopup, signInWithEmailAndPassword,
  GoogleAuthProvider, OAuthProvider
} from 'firebase/auth'
import { firebaseAuth } from '@/lib/firebase'

async function exchangeToken(idToken: string) {
  const res = await fetch('/api/auth/firebase', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  })
  if (!res.ok) throw new Error('Login failed')
}

export function LoginForm() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleProvider(provider: GoogleAuthProvider | OAuthProvider) {
    setLoading(true); setError(null)
    try {
      const { user } = await signInWithPopup(firebaseAuth, provider)
      await exchangeToken(await user.getIdToken())
      router.push('/app')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Erro ao fazer login')
    } finally {
      setLoading(false)
    }
  }

  async function handleEmail(e: React.FormEvent) {
    e.preventDefault(); setLoading(true); setError(null)
    try {
      const { user } = await signInWithEmailAndPassword(firebaseAuth, email, password)
      await exchangeToken(await user.getIdToken())
      router.push('/app')
    } catch {
      setError('Email ou senha incorretos')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="w-full max-w-sm space-y-4">
      <button
        onClick={() => handleProvider(new GoogleAuthProvider())}
        disabled={loading}
        className="w-full flex items-center justify-center gap-2 rounded-xl border px-4 py-3 font-medium hover:bg-surface-raised transition disabled:opacity-50"
      >
        Entrar com Google
      </button>

      <div className="relative flex items-center">
        <div className="flex-grow border-t border-gray-200" />
        <span className="mx-3 text-xs text-gray-400">ou</span>
        <div className="flex-grow border-t border-gray-200" />
      </div>

      <form onSubmit={handleEmail} className="space-y-3">
        <input
          type="email" placeholder="Email" value={email}
          onChange={e => setEmail(e.target.value)}
          className="w-full rounded-xl border px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-accent"
          required
        />
        <input
          type="password" placeholder="Senha" value={password}
          onChange={e => setPassword(e.target.value)}
          className="w-full rounded-xl border px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-accent"
          required
        />
        <button
          type="submit" disabled={loading}
          className="w-full rounded-xl bg-primary text-white px-4 py-3 font-medium hover:opacity-90 transition disabled:opacity-50"
        >
          {loading ? 'Entrando…' : 'Entrar'}
        </button>
      </form>

      {error && <p className="text-sm text-danger text-center">{error}</p>}
    </div>
  )
}
