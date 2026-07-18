const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:5000'
const ADMIN_KEY = process.env.ADMIN_API_KEY ?? 'dev-admin-key'

export async function adminApiClient<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Admin-Key': ADMIN_KEY,
    ...(options.headers as Record<string, string>),
  }
  const res = await fetch(`${BACKEND}${path}`, { ...options, headers })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`API ${res.status}: ${text}`)
  }
  return res.json() as Promise<T>
}
