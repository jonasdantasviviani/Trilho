// web/lib/api.ts
const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:5000'

interface ApiOptions extends RequestInit {
  cookie?: string
}

export async function apiClient<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const { cookie, ...rest } = options
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(rest.headers as Record<string, string>),
  }
  if (cookie) headers['Cookie'] = cookie

  const res = await fetch(`${BACKEND}${path}`, { ...rest, headers })
  if (!res.ok) {
    const error = await res.text()
    throw new Error(`API ${res.status}: ${error}`)
  }
  return res.json() as Promise<T>
}
