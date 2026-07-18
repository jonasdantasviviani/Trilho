import { render } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'

// vi.mock is hoisted by Vitest before any import — next/font won't hit the network
vi.mock('next/font/google', () => ({
  Inter: () => ({ variable: '--font-inter', className: 'inter' }),
}))

// Import after mock registration
const { default: RootLayout } = await import('../layout')

describe('RootLayout', () => {
  beforeEach(() => {
    document.body.className = ''
  })

  it('body has antialiased class', () => {
    const { container } = render(<RootLayout><div>child</div></RootLayout>)
    const body = container.querySelector('body')
    expect(body?.className).toContain('antialiased')
  })

  it('body has bg-bg class', () => {
    const { container } = render(<RootLayout><div>child</div></RootLayout>)
    const body = container.querySelector('body')
    expect(body?.className).toContain('bg-bg')
  })

  it('body has font-sans class', () => {
    const { container } = render(<RootLayout><div>child</div></RootLayout>)
    const body = container.querySelector('body')
    expect(body?.className).toContain('font-sans')
  })
})
