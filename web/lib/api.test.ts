import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

describe('apiClient', () => {
  beforeEach(() => mockFetch.mockReset())

  it('includes cookie header in requests', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: 'test' }),
    })
    const { apiClient } = await import('./api')
    await apiClient('/api/lines', { cookie: 'trilho_session=abc' })
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/lines'),
      expect.objectContaining({
        headers: expect.objectContaining({ Cookie: 'trilho_session=abc' }),
      })
    )
  })
})
