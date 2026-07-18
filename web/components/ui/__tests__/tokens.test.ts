// Verifies that the CSS file exports the expected custom property names.
// Uses a regex scan of the globals.css content rather than JSDOM.
import { readFileSync } from 'fs'
import { join } from 'path'
import { describe, it, expect } from 'vitest'

const css = readFileSync(join(process.cwd(), 'app/globals.css'), 'utf8')

describe('Design tokens in globals.css', () => {
  const required = [
    '--color-bg',
    '--color-surface',
    '--color-primary',
    '--color-accent',
    '--color-text-primary',
    '--color-text-secondary',
    '--crowd-empty',
    '--crowd-full',
  ]
  required.forEach(token => {
    it(`defines ${token}`, () => {
      expect(css).toContain(token)
    })
  })
})
