import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { adminApiClient } from '@/lib/admin-api'

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  const body = await req.json()

  try {
    const result = await adminApiClient(`/api/admin/users/${id}/vip`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    })
    return NextResponse.json(result)
  } catch (e: unknown) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : 'Failed' },
      { status: 500 }
    )
  }
}
