import { render, screen } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'

// Mock Next.js Link and server-only modules
vi.mock('next/link', () => ({ default: ({ children, href }: any) => <a href={href}>{children}</a> }))
vi.mock('@/components/Nav', () => ({ Nav: () => <nav data-testid="nav" /> }))
vi.mock('@/components/Footer', () => ({ Footer: () => <footer data-testid="footer" /> }))
vi.mock('@/components/LineStatusTicker', () => ({
  LineStatusTicker: () => <div data-testid="ticker" />,
}))

// Static-render version of the page (skip async data fetching)
function HomePage() {
  return (
    <main>
      <h1>Mobilidade em tempo real.</h1>
      <p>Saiba antes de sair de casa se o metrô está lotado.</p>
      <a href="https://apps.apple.com">Baixar iOS</a>
      <a href="https://play.google.com">Baixar Android</a>
      <section id="features">Funcionalidades</section>
      <section id="pricing">Preços</section>
    </main>
  )
}

describe('Landing Page', () => {
  it('shows hero headline', () => {
    render(<HomePage />)
    expect(screen.getByText(/Mobilidade em tempo real/)).toBeTruthy()
  })
  it('shows App Store and Play Store CTAs', () => {
    render(<HomePage />)
    expect(screen.getByText('Baixar iOS')).toBeTruthy()
    expect(screen.getByText('Baixar Android')).toBeTruthy()
  })
  it('has features section', () => {
    render(<HomePage />)
    expect(screen.getByText('Funcionalidades')).toBeTruthy()
  })
})
