'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient({
    defaultOptions: {
      queries: { retry: 2, retryDelay: (n) => Math.min(1000 * 2 ** n, 10000) },
    },
  }))
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>
}
