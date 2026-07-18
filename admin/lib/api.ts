const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000'

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
  body?: any
  headers?: Record<string, string>
}

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('admin_token') : null

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...options.headers,
  }

  if (token) {
    headers['X-Admin-Token'] = token
  }

  const res = await fetch(`${API_URL}${endpoint}`, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  })

  if (!res.ok) {
    throw new Error(`API Error: ${res.status}`)
  }

  return res.json()
}

export const api = {
  admin: {
    login: (email: string, password: string) =>
      request<{ token: string }>('/api/admin/login', {
        method: 'POST',
        body: { email, password },
      }),

    getUsers: (page = 1, size = 20) =>
      request<{ items: any[], total: number }>(`/api/admin/users?page=${page}&size=${size}`),

    getStats: () =>
      request<{ queries: number; users: number; premium: number; errorRate: number }>('/api/admin/stats'),

    getLineStatuses: () =>
      request<{ lines: any[] }>('/api/admin/lines/status'),

    getAnalytics: (period: 'week' | 'month' | 'year') =>
      request<{ data: any }>(`/api/admin/analytics?period=${period}`),

    toggleVip: (userId: string, isVip: boolean) =>
      request(`/api/admin/users/${userId}/vip`, {
        method: 'PATCH',
        body: { isVip },
      }),

    updateOlhoVivoToken: (token: string) =>
      request('/api/admin/settings/olhovivo', {
        method: 'PUT',
        body: { token },
      }),
  }
}
