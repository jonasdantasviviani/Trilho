import { render, screen } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { LoginForm } from './LoginForm'

vi.mock('@/lib/firebase', () => ({
  firebaseAuth: {},
}))

vi.mock('firebase/auth', () => ({
  signInWithPopup: vi.fn().mockResolvedValue({ user: { getIdToken: async () => 'fake-token' } }),
  signInWithEmailAndPassword: vi.fn().mockResolvedValue({ user: { getIdToken: async () => 'fake-token' } }),
  GoogleAuthProvider: vi.fn().mockImplementation(() => ({})),
  OAuthProvider: vi.fn().mockImplementation(() => ({})),
}))

vi.mock('next/navigation', () => ({
  useRouter: vi.fn().mockReturnValue({ push: vi.fn() }),
}))

describe('LoginForm', () => {
  it('renders Google login button', () => {
    render(<LoginForm />)
    expect(screen.getByRole('button', { name: /google/i })).toBeInTheDocument()
  })

  it('renders email input', () => {
    render(<LoginForm />)
    expect(screen.getByPlaceholderText(/email/i)).toBeInTheDocument()
  })

  it('submit button has bg-primary class', () => {
    render(<LoginForm />)
    const btn = screen.getByRole('button', { name: /^entrar$/i })
    expect(btn.className).toContain('bg-primary')
  })
})
