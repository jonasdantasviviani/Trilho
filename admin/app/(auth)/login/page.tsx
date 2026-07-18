import { signIn } from '@/auth'

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center px-4">
      <form
        action={async (data: FormData) => {
          'use server'
          await signIn('credentials', {
            email: data.get('email'),
            password: data.get('password'),
            redirectTo: '/',
          })
        }}
        className="w-full max-w-sm space-y-4"
      >
        <h1 className="text-2xl font-bold text-center">Trilho Admin</h1>
        <input name="email" type="email" placeholder="Email"
          className="w-full border rounded-xl px-4 py-3 text-sm" required />
        <input name="password" type="password" placeholder="Senha"
          className="w-full border rounded-xl px-4 py-3 text-sm" required />
        <button type="submit"
          className="w-full bg-gray-900 text-white rounded-xl px-4 py-3 text-sm font-medium hover:bg-gray-700">
          Entrar
        </button>
      </form>
    </main>
  )
}
