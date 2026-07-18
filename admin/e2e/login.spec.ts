import { test, expect } from '@playwright/test'

test('A1: admin login page loads', async ({ page }) => {
  await page.goto('/login')
  await expect(page.getByText('Trilho Admin')).toBeVisible()
  await expect(page.locator('input[type=email]')).toBeVisible()
})

test('A2: wrong password stays on login page', async ({ page }) => {
  await page.goto('/login')
  await page.fill('input[type=email]', 'admin@trilho.app')
  await page.fill('input[type=password]', 'wrongpassword')
  await page.click('button[type=submit]')
  await expect(page).toHaveURL(/\/login/)
})

test('A5: unauthenticated access to /users redirects to login', async ({ page }) => {
  await page.goto('/users')
  await expect(page).toHaveURL(/\/login/)
})
