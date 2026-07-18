export const dynamic = 'force-dynamic'
import { LoginForm } from '@/components/LoginForm'
import { LogoLockup } from '@/components/ui/Logo'
import Link from 'next/link'

export default function LoginPage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-4 bg-bg">
      <div className="w-full max-w-sm space-y-8">
        <div className="text-center space-y-2">
          <div className="flex justify-center mb-4">
            <LogoLockup />
          </div>
          <p className="text-sm text-text-secondary">Entre para acessar o mapa completo</p>
        </div>

        <LoginForm />

        <p className="text-center text-xs text-text-disabled">
          Acesso ao mapa requer plano premium.{' '}
          <Link href="/pricing" className="text-accent hover:underline">Ver planos</Link>
        </p>
      </div>
    </main>
  )
}
