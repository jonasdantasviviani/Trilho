import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { LineStatusTicker } from './LineStatusTicker'

const mockLines = [
  { code: 'L1', name: 'Linha 1-Azul', currentStatus: 'Normal',     statusMessage: null },
  { code: 'L2', name: 'Linha 2-Verde', currentStatus: 'Paralisada', statusMessage: 'Falha técnica' },
]

describe('LineStatusTicker', () => {
  it('renders each line name', () => {
    render(<LineStatusTicker lines={mockLines} />)
    expect(screen.getByText('Linha 1-Azul')).toBeTruthy()
    expect(screen.getByText('Linha 2-Verde')).toBeTruthy()
  })

  it('shows empty state message when no lines', () => {
    render(<LineStatusTicker lines={[]} />)
    expect(screen.getByText(/indisponível/i)).toBeTruthy()
  })

  it('status badge for Normal uses text-success', () => {
    const { container } = render(<LineStatusTicker lines={[mockLines[0]]} />)
    const badge = container.querySelector('.text-success')
    expect(badge).toBeTruthy()
  })

  it('status badge for Paralisada uses text-danger', () => {
    const { container } = render(<LineStatusTicker lines={[mockLines[1]]} />)
    const badge = container.querySelector('.text-danger')
    expect(badge).toBeTruthy()
  })
})
