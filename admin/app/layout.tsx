import './globals.css'

export const metadata = {
  title: 'Trilho Admin',
  description: 'Dashboard administrativo do Trilho',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  )
}
