'use client'
import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'

interface Props {
  userId: string
  initialIsVip: boolean
  initialEmail: string | null
}

export function VipToggle({ userId, initialIsVip, initialEmail }: Props) {
  const [isVip, setIsVip] = useState(initialIsVip)
  const queryClient = useQueryClient()

  const { mutate, isPending } = useMutation({
    mutationFn: async (nextVip: boolean) => {
      const res = await fetch(`/api/admin/users/${userId}/vip`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isVip: nextVip, vipEmail: nextVip ? initialEmail : null }),
      })
      if (!res.ok) throw new Error('Failed to update VIP')
      return res.json()
    },
    onMutate: (nextVip) => { const prev = isVip; setIsVip(nextVip); return prev },
    onError: (_err, _vars, prev) => setIsVip(prev as boolean),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-users'] }),
  })

  return (
    <input
      type="checkbox"
      checked={isVip}
      disabled={isPending}
      onChange={(e) => mutate(e.target.checked)}
      className="h-4 w-4 rounded cursor-pointer accent-blue-600"
    />
  )
}
