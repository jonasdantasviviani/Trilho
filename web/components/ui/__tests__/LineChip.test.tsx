import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { LineChip } from '../LineChip'

describe('LineChip', () => {
  it('renders line code', () => {
    render(<LineChip code="L1" color="#0055FF" />)
    expect(screen.getByText('L1')).toBeTruthy()
  })
  it('applies background color via style', () => {
    const { container } = render(<LineChip code="L1" color="#0055FF" />)
    expect((container.firstChild as HTMLElement).style.backgroundColor).toBe('rgb(0, 85, 255)')
  })
})
