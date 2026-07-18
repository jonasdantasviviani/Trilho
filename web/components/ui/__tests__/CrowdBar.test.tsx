import { render } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { CrowdBar } from '../CrowdBar'

describe('CrowdBar', () => {
  it('renders a filled segment matching density', () => {
    const { container } = render(<CrowdBar density={0.5} />)
    const fill = container.querySelector('[data-testid="crowd-fill"]') as HTMLElement
    expect(fill).toBeTruthy()
    expect(fill.style.width).toBe('50%')
  })
  it('clamps density above 1 to 100%', () => {
    const { container } = render(<CrowdBar density={1.5} />)
    const fill = container.querySelector('[data-testid="crowd-fill"]') as HTMLElement
    expect(fill.style.width).toBe('100%')
  })
})
