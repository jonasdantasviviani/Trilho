import { describe, it, expect } from 'vitest'
import { shouldProtect, shouldRequirePremium } from './middleware'

describe('middleware route logic', () => {
  it('protects /app routes', () => {
    expect(shouldProtect('/app')).toBe(true)
    expect(shouldProtect('/app/line/L1')).toBe(true)
  })

  it('does not protect public routes', () => {
    expect(shouldProtect('/')).toBe(false)
    expect(shouldProtect('/login')).toBe(false)
    expect(shouldProtect('/pricing')).toBe(false)
  })
})
