// web/app/api/auth/firebase/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { apiClient } from '@/lib/api'
import { COOKIE_NAME } from '@/lib/auth'

export async function POST(req: NextRequest) {
  const { idToken } = await req.json()
  if (!idToken) {
    return NextResponse.json({ error: 'idToken required' }, { status: 400 })
  }

  try {
    const { token } = await apiClient<{ token: string }>(
      '/api/auth/firebase',
      { method: 'POST', body: JSON.stringify({ idToken }) }
    )

    const res = NextResponse.json({ ok: true })
    res.cookies.set(COOKIE_NAME, token, {
      httpOnly: true,
      sameSite: 'strict',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      maxAge: 60 * 60 * 24 * 30, // 30 days
    })
    return res
  } catch {
    return NextResponse.json({ error: 'Authentication failed' }, { status: 401 })
  }
}
