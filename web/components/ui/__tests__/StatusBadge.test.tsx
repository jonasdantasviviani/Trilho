import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { StatusBadge } from '../StatusBadge'

describe('StatusBadge', () => {
  it('renders status text', () => {
    render(<StatusBadge status="Normal" />)
    expect(screen.getByText('Normal')).toBeTruthy()
  })
  it('uses green color class for Normal status', () => {
    const { container } = render(<StatusBadge status="Normal" />)
    expect((container.firstChild as HTMLElement).className).toContain('text-success')
  })
  it('uses red color class for Paralisada status', () => {
    const { container } = render(<StatusBadge status="Paralisada" />)
    expect((container.firstChild as HTMLElement).className).toContain('text-danger')
  })
})
