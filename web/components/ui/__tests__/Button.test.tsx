import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { Button } from '../Button'

describe('Button', () => {
  it('renders label text', () => {
    render(<Button>Entrar</Button>)
    expect(screen.getByText('Entrar')).toBeTruthy()
  })
  it('primary variant has bg-primary class', () => {
    const { container } = render(<Button variant="primary">X</Button>)
    expect(container.firstChild).toHaveClass('bg-primary')
  })
  it('ghost variant has border class', () => {
    const { container } = render(<Button variant="ghost">X</Button>)
    expect(container.firstChild).toHaveClass('border')
  })
  it('is disabled when disabled prop is set', () => {
    render(<Button disabled>X</Button>)
    expect(screen.getByRole('button')).toBeDisabled()
  })
})
