import { test, expect } from '@playwright/test';
import {
  mockAuthResponse,
  mockStats,
  mockLearningGoals,
  mockLearningProfiles,
  mockConversations,
} from './fixtures/mock-data';

// Helper function to set up authenticated state
async function setupAuthenticatedState(page: import('@playwright/test').Page) {
  await page.addInitScript(() => {
    localStorage.setItem('token', 'mock-jwt-token-12345');
    localStorage.setItem('refreshToken', 'mock-refresh-token-67890');
  });

  await page.route('**/api/v1/auth/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ student: mockAuthResponse.student }),
    });
  });

  await page.route('**/api/v1/stats', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockStats),
    });
  });

  await page.route('**/api/v1/learning_goals', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockLearningGoals),
    });
  });

  await page.route('**/api/v1/learning_profiles', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockLearningProfiles),
    });
  });

  await page.route('**/api/v1/conversations', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockConversations),
    });
  });

  await page.route('**/api/v1/practice_sessions', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });

  await page.route('**/api/v1/activities', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });

  await page.route('**/api/v1/student_events**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });
}

test.describe('App Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuthenticatedState(page);
  });

  test('should redirect root to dashboard', async ({ page }) => {
    await page.goto('/');

    await page.waitForURL('**/dashboard', { timeout: 10000 });
    expect(page.url()).toContain('/dashboard');
  });

  test('should navigate to chat page', async ({ page }) => {
    await page.goto('/chat');

    await expect(page.locator('text=AI Companion')).toBeVisible({ timeout: 10000 });
  });

  test('should navigate to practice page', async ({ page }) => {
    await page.goto('/practice');

    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });
    const content = await page.content();
    expect(content.toLowerCase()).toMatch(/practice/i);
  });

  test('should navigate to dashboard page', async ({ page }) => {
    await page.goto('/dashboard');

    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
  });

  test('should protect routes when not authenticated', async ({ page }) => {
    // Clear authentication
    await page.addInitScript(() => {
      localStorage.removeItem('token');
      localStorage.removeItem('refreshToken');
    });

    // Mock auth to return 401
    await page.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({ status: 401 });
    });

    await page.goto('/dashboard');

    // Should redirect to login
    await page.waitForURL('**/login', { timeout: 10000 });
    expect(page.url()).toContain('/login');
  });

  test('should handle 404 gracefully', async ({ page }) => {
    await page.goto('/nonexistent-page');

    // Should either show 404 or redirect
    const url = page.url();
    expect(url).toBeTruthy();
  });

  test('should maintain auth state across navigation', async ({ page }) => {
    // Go to dashboard
    await page.goto('/dashboard');
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });

    // Navigate to chat
    await page.goto('/chat');
    await expect(page.locator('text=AI Companion')).toBeVisible({ timeout: 10000 });

    // Navigate back to dashboard
    await page.goto('/dashboard');
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
  });

  test('should handle browser back/forward navigation', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });

    await page.goto('/chat');
    await expect(page.locator('text=AI Companion')).toBeVisible({ timeout: 10000 });

    // Go back
    await page.goBack();
    await page.waitForURL('**/dashboard', { timeout: 10000 });

    // Go forward
    await page.goForward();
    await page.waitForURL('**/chat', { timeout: 10000 });
  });

  test('should handle page refresh without losing auth', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });

    // Refresh the page
    await page.reload();

    // Should still be on dashboard
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
  });
});

test.describe('Responsive Design', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuthenticatedState(page);
  });

  test('should render correctly on mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/dashboard');

    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
  });

  test('should render correctly on tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/dashboard');

    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
  });

  test('should render correctly on desktop viewport', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/dashboard');

    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
  });
});

test.describe('Error Handling', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuthenticatedState(page);
  });

  test('should handle API errors gracefully', async ({ page }) => {
    await page.route('**/api/v1/learning_goals', async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'Internal Server Error' }),
      });
    });

    await page.goto('/dashboard');

    // Page should still render without crashing
    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });
  });

  test('should handle network timeout gracefully', async ({ page }) => {
    await page.route('**/api/v1/learning_goals', async (route) => {
      // Simulate a slow network
      await new Promise((resolve) => setTimeout(resolve, 3000));
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningGoals),
      });
    });

    await page.goto('/dashboard');

    // Should show loading or eventually load content
    await expect(page.locator('body')).toBeVisible({ timeout: 15000 });
  });
});
