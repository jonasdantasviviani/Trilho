'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import {
  LayoutDashboard,
  Users,
  Train,
  BarChart3,
  Settings,
  LogOut,
  Menu,
  X,
  Train as TrainIcon,
  CreditCard
} from 'lucide-react'

const navItems = [
  { href: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { href: '/dashboard/users', icon: Users, label: 'Usuários' },
  { href: '/dashboard/subscriptions', icon: CreditCard, label: 'Assinaturas' },
  { href: '/dashboard/lines', icon: Train, label: 'Linhas' },
  { href: '/dashboard/analytics', icon: BarChart3, label: 'Analytics' },
  { href: '/dashboard/settings', icon: Settings, label: 'Configurações' },
]

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const [sidebarOpen, setSidebarOpen] = useState(true)

  const handleLogout = () => {
    localStorage.removeItem('admin_token')
    router.push('/')
  }

  return (
    <div className="admin-layout">
      <aside className="sidebar" style={{ width: sidebarOpen ? 260 : 70 }}>
        <div className="sidebar-header">
          <div className="sidebar-logo">
            <TrainIcon size={24} />
            {sidebarOpen && <span>Trilho</span>}
          </div>
        </div>

        <nav className="sidebar-nav">
          {navItems.map((item) => {
            const isActive = pathname === item.href
            const Icon = item.icon
            return (
              <Link key={item.href} href={item.href} className={`nav-item ${isActive ? 'active' : ''}`}>
                <Icon size={20} />
                {sidebarOpen && <span>{item.label}</span>}
              </Link>
            )
          })}

          <button onClick={handleLogout} className="nav-item" style={{ marginTop: 'auto', width: '100%' }}>
            <LogOut size={20} />
            {sidebarOpen && <span>Sair</span>}
          </button>
        </nav>

        <button 
          onClick={() => setSidebarOpen(!sidebarOpen)}
          style={{
            position: 'fixed',
            top: 16,
            left: sidebarOpen ? 244 : 54,
            padding: 8,
            borderRadius: 8,
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            zIndex: 100,
            transition: 'left 0.2s'
          }}
        >
          {sidebarOpen ? <X size={20} /> : <Menu size={20} />}
        </button>
      </aside>

      <main className="main-content">
        {children}
      </main>
    </div>
  )
}
