import { ButtonHTMLAttributes } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'ghost' | 'outline'
  size?: 'sm' | 'md' | 'lg'
  fullWidth?: boolean
}

const variantClasses: Record<NonNullable<ButtonProps['variant']>, string> = {
  primary: 'bg-primary text-white hover:opacity-90',
  ghost:   'border border-border text-text-secondary hover:text-text-primary hover:border-text-secondary',
  outline: 'border border-primary text-primary hover:bg-primary hover:text-white',
}

const sizeClasses: Record<NonNullable<ButtonProps['size']>, string> = {
  sm: 'px-4 py-2 text-xs',
  md: 'px-5 py-3 text-sm',
  lg: 'px-7 py-4 text-base',
}

export function Button({
  variant = 'primary',
  size = 'md',
  fullWidth = false,
  className = '',
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={[
        'inline-flex items-center justify-center gap-2 rounded-xl font-semibold',
        'transition-all duration-150 disabled:opacity-50 disabled:cursor-not-allowed',
        variantClasses[variant],
        sizeClasses[size],
        fullWidth ? 'w-full' : '',
        className,
      ].filter(Boolean).join(' ')}
      {...props}
    >
      {children}
    </button>
  )
}
