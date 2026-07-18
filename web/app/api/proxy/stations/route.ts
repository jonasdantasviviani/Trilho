import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { COOKIE_NAME } from '@/lib/auth'
import { apiClient } from '@/lib/api'

export async function GET(_req: NextRequest) {
  const cookieStore = await cookies()
  const token = cookieStore.get(COOKIE_NAME)?.value

  try {
    const data = await apiClient('/api/stations', {
      cookie: token ? `${COOKIE_NAME}=${token}` : undefined,
    })
    return NextResponse.json(data)
  } catch {
    return NextResponse.json([], { status: 200 })
  }
}
