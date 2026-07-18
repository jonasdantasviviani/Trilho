import { describe, it, expect } from 'vitest'
import { parseJwtCookie, JwtPayload } from './auth'

describe('parseJwtCookie', () => {
  it('returns null for empty string', () => {
    expect(parseJwtCookie('')).toBeNull()
  })

  it('returns null for invalid token', () => {
    expect(parseJwtCookie('not.a.token')).toBeNull()
  })

  it('parses valid JWT payload without verifying signature', () => {
    const payload: JwtPayload = {
      sub: 'user-123',
      email: 'test@example.com',
      isPremium: true,
      isVip: false,
      exp: Math.floor(Date.now() / 1000) + 3600,
    }
    const encoded = btoa(JSON.stringify(payload))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
    const fakeToken = `header.${encoded}.sig`
    const result = parseJwtCookie(fakeToken)
    expect(result?.sub).toBe('user-123')
    expect(result?.isPremium).toBe(true)
  })
})
