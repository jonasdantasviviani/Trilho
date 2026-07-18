import { test, expect } from '@playwright/test'

test('F1: landing page loads and shows app store links', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('Trilho')).toBeVisible()
  await expect(page.getByText('App Store')).toBeVisible()
  await expect(page.getByText('Google Play')).toBeVisible()
})

test('F3: unauthenticated user redirected from /app to /login', async ({ page }) => {
  await page.goto('/app')
  await expect(page).toHaveURL(/\/login/)
})
