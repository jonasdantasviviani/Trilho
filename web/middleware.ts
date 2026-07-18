// web/middleware.ts
import { NextRequest, NextResponse } from 'next/server'
import { verifySessionToken, COOKIE_NAME } from '@/lib/auth'

export function shouldProtect(pathname: string) {
  return pathname.startsWith('/app')
}

export function shouldRequirePremium(pathname: string) {
  return pathname.startsWith('/app')
}

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl

  if (!shouldProtect(pathname)) return NextResponse.next()

  const token = req.cookies.get(COOKIE_NAME)?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', req.url))
  }

  const session = await verifySessionToken(token)
  if (!session) {
    const res = NextResponse.redirect(new URL('/login', req.url))
    res.cookies.delete(COOKIE_NAME)
    return res
  }

  if (!session.isPremium && !session.isVip) {
    return NextResponse.redirect(
      new URL('/pricing?reason=premium_required', req.url)
    )
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/app/:path*'],
}
