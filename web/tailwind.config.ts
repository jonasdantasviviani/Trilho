import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        bg:             'var(--color-bg)',
        surface:        'var(--color-surface)',
        'surface-raised':'var(--color-surface-raised)',
        // 'border' token generates border-border, bg-border utilities (intentional naming)
        border:         'var(--color-border)',
        primary:        'var(--color-primary)',
        accent:         'var(--color-accent)',
        'text-primary': 'var(--color-text-primary)',
        'text-secondary':'var(--color-text-secondary)',
        'text-disabled': 'var(--color-text-disabled)',
        success:        'var(--color-success)',
        warning:        'var(--color-warning)',
        danger:         'var(--color-danger)',
        'primary-dim':  'var(--color-primary-dim)',
        'accent-dim':   'var(--color-accent-dim)',
        'crowd-empty':    'var(--crowd-empty)',
        'crowd-low':      'var(--crowd-low)',
        'crowd-moderate': 'var(--crowd-moderate)',
        'crowd-high':     'var(--crowd-high)',
        'crowd-full':     'var(--crowd-full)',
      },
      fontFamily: {
        sans: ['Inter', 'var(--font-inter)', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        // sm/md intentionally override Tailwind's default shadow-sm/shadow-md with project token values
        sm: 'var(--shadow-sm)',
        md: 'var(--shadow-md)',
        'glow-primary': 'var(--shadow-glow-primary)',
        'glow-accent':  'var(--shadow-glow-accent)',
      },
      transitionDuration: {
        fast:   '150',
        smooth: '300',
        slow:   '500',
      },
    },
  },
  plugins: [],
}
export default config
