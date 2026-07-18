import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { VipToggle } from './VipToggle'

// ---------------------------------------------------------------------------
// Global fetch mock
// ---------------------------------------------------------------------------
const mockFetch = vi.fn()
vi.stubGlobal('fetch', mockFetch)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })
}

function wrap(ui: React.ReactElement, client?: QueryClient) {
  return (
    <QueryClientProvider client={client ?? makeQueryClient()}>
      {ui}
    </QueryClientProvider>
  )
}

/** Returns a resolved Response-like object that fetch can return. */
function okResponse(body: object = {}) {
  return { ok: true, json: async () => body }
}

/** Returns a rejected (non-ok) Response-like object. */
function errorResponse(status = 500) {
  return { ok: false, status, json: async () => ({ error: 'Server error' }) }
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

beforeEach(() => {
  mockFetch.mockReset()
})

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('VipToggle', () => {
  // ------------------------------------------------------------------
  // Rendering
  // ------------------------------------------------------------------

  describe('rendering', () => {
    it('renders a checkbox for a non-VIP user (unchecked)', () => {
      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail={null} />))

      const checkbox = screen.getByRole('checkbox')
      expect(checkbox).toBeInTheDocument()
      expect(checkbox).not.toBeChecked()
    })

    it('renders a checkbox for a VIP user (checked)', () => {
      render(wrap(<VipToggle userId="u1" initialIsVip={true} initialEmail="vip@example.com" />))

      const checkbox = screen.getByRole('checkbox')
      expect(checkbox).toBeInTheDocument()
      expect(checkbox).toBeChecked()
    })

    it('checkbox is enabled when idle', () => {
      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail={null} />))

      expect(screen.getByRole('checkbox')).not.toBeDisabled()
    })
  })

  // ------------------------------------------------------------------
  // Optimistic update
  // ------------------------------------------------------------------

  describe('optimistic update', () => {
    it('toggles the checkbox immediately before the API responds', async () => {
      // Delay resolution so we can assert the intermediate state.
      let resolve: (v: unknown) => void
      mockFetch.mockReturnValueOnce(
        new Promise((res) => { resolve = res }),
      )

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail="x@y.com" />))
      const checkbox = screen.getByRole('checkbox')

      expect(checkbox).not.toBeChecked()
      fireEvent.click(checkbox)

      // Optimistic update: already checked even though fetch hasn't resolved yet.
      expect(checkbox).toBeChecked()

      // Let the fetch complete so timers / state settle before test exits.
      resolve!(okResponse({ isVip: true }))
      await waitFor(() => expect(checkbox).not.toBeDisabled())
    })
  })

  // ------------------------------------------------------------------
  // Loading state
  // ------------------------------------------------------------------

  describe('loading state', () => {
    it('disables the checkbox while the API request is in flight', async () => {
      let resolve: (v: unknown) => void
      mockFetch.mockReturnValueOnce(
        new Promise((res) => { resolve = res }),
      )

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail={null} />))
      const checkbox = screen.getByRole('checkbox')

      fireEvent.click(checkbox)

      // isPending === true → disabled
      await waitFor(() => expect(checkbox).toBeDisabled())

      // Resolve the request so state settles.
      resolve!(okResponse())
      await waitFor(() => expect(checkbox).not.toBeDisabled())
    })

    it('re-enables the checkbox after a successful response', async () => {
      mockFetch.mockResolvedValueOnce(okResponse({ isVip: true }))

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail="x@y.com" />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() => expect(screen.getByRole('checkbox')).not.toBeDisabled())
    })
  })

  // ------------------------------------------------------------------
  // API call details
  // ------------------------------------------------------------------

  describe('API call', () => {
    it('calls PATCH /api/admin/users/:id/vip when toggled on', async () => {
      mockFetch.mockResolvedValueOnce(okResponse({ isVip: true }))

      render(wrap(<VipToggle userId="abc123" initialIsVip={false} initialEmail="x@y.com" />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() =>
        expect(mockFetch).toHaveBeenCalledWith(
          '/api/admin/users/abc123/vip',
          expect.objectContaining({ method: 'PATCH' }),
        ),
      )
    })

    it('sends { isVip: true, vipEmail } when turning VIP on', async () => {
      mockFetch.mockResolvedValueOnce(okResponse({ isVip: true }))

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail="vip@example.com" />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() => expect(mockFetch).toHaveBeenCalledTimes(1))

      const [, options] = mockFetch.mock.calls[0] as [string, RequestInit]
      const body = JSON.parse(options.body as string)
      expect(body).toEqual({ isVip: true, vipEmail: 'vip@example.com' })
    })

    it('sends { isVip: false, vipEmail: null } when turning VIP off', async () => {
      mockFetch.mockResolvedValueOnce(okResponse({ isVip: false }))

      render(wrap(<VipToggle userId="u1" initialIsVip={true} initialEmail="vip@example.com" />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() => expect(mockFetch).toHaveBeenCalledTimes(1))

      const [, options] = mockFetch.mock.calls[0] as [string, RequestInit]
      const body = JSON.parse(options.body as string)
      expect(body).toEqual({ isVip: false, vipEmail: null })
    })

    it('sends Content-Type: application/json header', async () => {
      mockFetch.mockResolvedValueOnce(okResponse())

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail={null} />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() => expect(mockFetch).toHaveBeenCalledTimes(1))

      const [, options] = mockFetch.mock.calls[0] as [string, RequestInit]
      expect((options.headers as Record<string, string>)['Content-Type']).toBe('application/json')
    })

    it('uses the correct userId in the URL', async () => {
      mockFetch.mockResolvedValueOnce(okResponse())

      render(wrap(<VipToggle userId="specific-user-id" initialIsVip={false} initialEmail={null} />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() => expect(mockFetch).toHaveBeenCalledTimes(1))

      const [url] = mockFetch.mock.calls[0] as [string, RequestInit]
      expect(url).toBe('/api/admin/users/specific-user-id/vip')
    })
  })

  // ------------------------------------------------------------------
  // Error handling / rollback
  // ------------------------------------------------------------------

  describe('error handling', () => {
    it('reverts the optimistic update when the API returns a non-ok response', async () => {
      mockFetch.mockResolvedValueOnce(errorResponse(500))

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail={null} />))
      const checkbox = screen.getByRole('checkbox')

      fireEvent.click(checkbox)
      // Optimistic: checked immediately.
      expect(checkbox).toBeChecked()

      // After error callback: should revert to original unchecked state.
      await waitFor(() => expect(checkbox).not.toBeChecked())
    })

    it('reverts to checked when toggling off fails', async () => {
      mockFetch.mockResolvedValueOnce(errorResponse(500))

      render(wrap(<VipToggle userId="u1" initialIsVip={true} initialEmail="vip@example.com" />))
      const checkbox = screen.getByRole('checkbox')

      fireEvent.click(checkbox)
      // Optimistic: unchecked immediately.
      expect(checkbox).not.toBeChecked()

      // After error: should revert to original checked state.
      await waitFor(() => expect(checkbox).toBeChecked())
    })

    it('re-enables the checkbox after an API error', async () => {
      mockFetch.mockResolvedValueOnce(errorResponse())

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail={null} />))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() => expect(screen.getByRole('checkbox')).not.toBeDisabled())
    })
  })

  // ------------------------------------------------------------------
  // Query invalidation on success
  // ------------------------------------------------------------------

  describe('query invalidation', () => {
    it('invalidates the admin-users query after a successful mutation', async () => {
      mockFetch.mockResolvedValueOnce(okResponse({ isVip: true }))

      const client = makeQueryClient()
      const spy = vi.spyOn(client, 'invalidateQueries')

      render(wrap(<VipToggle userId="u1" initialIsVip={false} initialEmail="x@y.com" />, client))
      fireEvent.click(screen.getByRole('checkbox'))

      await waitFor(() =>
        expect(spy).toHaveBeenCalledWith({ queryKey: ['admin-users'] }),
      )
    })
  })
})
