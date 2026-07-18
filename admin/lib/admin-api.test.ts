import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

describe('adminApiClient', () => {
  beforeEach(() => mockFetch.mockReset())

  it('sends X-Admin-Key header', async () => {
    mockFetch.mockResolvedValueOnce({ ok: true, json: async () => ({ items: [] }) })
    const { adminApiClient } = await import('./admin-api')
    await adminApiClient('/api/admin/users')
    expect(mockFetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({ 'X-Admin-Key': expect.any(String) }),
      })
    )
  })

  it('throws on 403', async () => {
    mockFetch.mockResolvedValueOnce({ ok: false, status: 403, text: async () => 'Forbidden' })
    const { adminApiClient } = await import('./admin-api')
    await expect(adminApiClient('/api/admin/users')).rejects.toThrow('403')
  })
})
