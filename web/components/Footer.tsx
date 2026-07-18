import Link from 'next/link'
import { LogoLockup } from './ui/Logo'

export function Footer() {
  return (
    <footer className="border-t border-border bg-surface mt-24">
      <div className="max-w-5xl mx-auto px-6 py-12 flex flex-col md:flex-row items-center justify-between gap-6">
        <LogoLockup />
        <p className="text-text-disabled text-xs">
          Mobilidade em tempo real
        </p>
        <div className="flex gap-6 text-xs text-text-secondary">
          <Link href="/privacy" className="hover:text-text-primary transition-colors">Privacidade</Link>
          <Link href="/terms"   className="hover:text-text-primary transition-colors">Termos</Link>
        </div>
      </div>
    </footer>
  )
}
