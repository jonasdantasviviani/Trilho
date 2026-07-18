import Link from 'next/link'
import { LogoLockup } from './ui/Logo'
import { Button } from './ui/Button'

export function Nav() {
  return (
    <nav className="fixed top-0 inset-x-0 z-50 flex items-center justify-between px-6 py-4 bg-bg/80 backdrop-blur-md border-b border-border">
      <Link href="/" className="hover:opacity-80 transition-opacity">
        <LogoLockup />
      </Link>

      <div className="hidden md:flex items-center gap-8 text-sm text-text-secondary">
        <Link href="#features" className="hover:text-text-primary transition-colors">Funcionalidades</Link>
        <Link href="/pricing"  className="hover:text-text-primary transition-colors">Preços</Link>
      </div>

      <Link href="/login">
        <Button variant="ghost" size="sm">Entrar</Button>
      </Link>
    </nav>
  )
}
