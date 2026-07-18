import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
})

export const metadata: Metadata = {
  title: 'Trilho — Mobilidade em tempo real',
  description: 'Saiba a lotação do metrô e CPTM antes de sair de casa.',
}

export const viewport: Viewport = {
  themeColor: '#0A0A14',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={inter.variable}>
      <body className="font-sans antialiased bg-bg text-text-primary min-h-screen">
        {children}
      </body>
    </html>
  )
}
