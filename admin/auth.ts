import NextAuth from 'next-auth'
import Credentials from 'next-auth/providers/credentials'
import { authConfig } from './auth.config'
import { adminApiClient } from '@/lib/admin-api'

export const { handlers, auth, signIn, signOut } = NextAuth({
  ...authConfig,
  providers: [
    Credentials({
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Senha', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null
        try {
          const result = await adminApiClient<{ id: string; email: string }>(
            '/api/admin/auth',
            {
              method: 'POST',
              body: JSON.stringify({
                email: credentials.email,
                password: credentials.password,
              }),
            }
          )
          return { id: result.id ?? result.email, email: result.email }
        } catch {
          return null
        }
      },
    }),
  ],
})
