// web/lib/auth.ts
import { cookies } from 'next/headers'
import { jwtVerify } from 'jose'

export interface JwtPayload {
  sub: string
  email?: string
  isPremium: boolean
  isVip: boolean
  exp?: number
}

const JWT_SECRET = new TextEncoder().encode(
  process.env.JWT_SECRET ?? 'dev-secret-32-chars-minimum-here'
)
export const COOKIE_NAME = 'trilho_session'

// Parse JWT payload without signature verification (for client-side display)
export function parseJwtCookie(token: string): JwtPayload | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))
    return payload as JwtPayload
  } catch {
    return null
  }
}

// Verify JWT (server-side, with signature check)
export async function verifySessionToken(token: string): Promise<JwtPayload | null> {
  try {
    const { payload } = await jwtVerify(token, JWT_SECRET)
    // Map custom claims emitted by GenerateJwtWithClaims (.NET backend)
    return {
      sub: payload.sub ?? '',
      email: payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] as string | undefined
        ?? payload.email as string | undefined,
      isPremium: payload['isPremium'] === 'true',
      isVip: payload['isVip'] === 'true',
      exp: payload.exp,
    }
  } catch {
    return null
  }
}

// Get current session from cookie (server component)
export async function getSession(): Promise<JwtPayload | null> {
  const cookieStore = await cookies()
  const token = cookieStore.get(COOKIE_NAME)?.value
  if (!token) return null
  return verifySessionToken(token)
}
