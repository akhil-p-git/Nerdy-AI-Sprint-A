import { test, expect, Page } from '@playwright/test';
import { mockAuthResponse, mockStats, mockLearningGoals, mockLearningProfiles } from './fixtures/mock-data';

// Helper function to set up all API mocks - must be called BEFORE page.goto()
async function setupApiMocks(page: Page) {
  // Mock auth login - the app sends { nerdy_token: ... }
  await page.route('**/api/v1/auth/login', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockAuthResponse),
    });
  });

  // Mock auth me endpoint
  await page.route('**/api/v1/auth/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ student: mockAuthResponse.student }),
    });
  });

  // Mock stats
  await page.route('**/api/v1/stats**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockStats),
    });
  });

  // Mock learning goals
  await page.route('**/api/v1/learning_goals**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockLearningGoals),
    });
  });

  // Mock learning profiles
  await page.route('**/api/v1/learning_profiles**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockLearningProfiles),
    });
  });

  // Mock student events
  await page.route('**/api/v1/student_events**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });

  // Mock activities
  await page.route('**/api/v1/activities**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });

  // Catch-all for any other API calls
  await page.route('**/api/v1/**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({}),
    });
  });
}

test.describe('Authentication Flow', () => {
  test('should display login page elements', async ({ page }) => {
    // Set up mocks for unauthenticated state
    await page.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({ status: 401 });
    });

    await page.goto('/login');

    // Wait for page to fully load
    await page.waitForLoadState('networkidle');

    // Check for login page elements
    await expect(page.locator('h1')).toContainText('Nerdy AI Companion');
    await expect(page.locator('input')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('should redirect to login when not authenticated', async ({ page }) => {
    // Mock auth to return 401
    await page.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({ status: 401 });
    });

    await page.goto('/dashboard');

    // Wait for redirect
    await page.waitForLoadState('networkidle');
    await page.waitForURL(/login/, { timeout: 10000 });
  });

  test('should login successfully', async ({ page }) => {
    // First, mock unauthenticated state for login page
    await page.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({ status: 401 });
    });

    // Mock login endpoint
    await page.route('**/api/v1/auth/login', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockAuthResponse),
      });
    });

    // Mock dashboard endpoints for after login
    await page.route('**/api/v1/stats**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockStats),
      });
    });

    await page.route('**/api/v1/learning_goals**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningGoals),
      });
    });

    await page.route('**/api/v1/learning_profiles**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningProfiles),
      });
    });

    await page.route('**/api/v1/student_events**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    });

    await page.route('**/api/v1/activities**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    });

    await page.goto('/login');
    await page.waitForLoadState('networkidle');

    // Fill in token and submit
    await page.locator('input').fill('test-token');
    await page.locator('button[type="submit"]').click();

    // After login, update auth/me to return authenticated
    await page.unroute('**/api/v1/auth/me');
    await page.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ student: mockAuthResponse.student }),
      });
    });

    // Should redirect to dashboard
    await page.waitForURL(/dashboard|^\/$/, { timeout: 15000 });
  });

  test('should persist auth across reload', async ({ page }) => {
    // Set localStorage FIRST via addInitScript (runs before page load)
    await page.addInitScript(() => {
      localStorage.setItem('token', 'mock-jwt-token-12345');
      localStorage.setItem('refreshToken', 'mock-refresh-token-67890');
    });

    // Set up routes WITHOUT the catch-all that interferes with specific routes
    // (Playwright matches routes from last to first, so catch-all would match first)
    await page.route('**/api/v1/auth/me', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ student: mockAuthResponse.student }),
      });
    });

    await page.route('**/api/v1/stats**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockStats),
      });
    });

    await page.route('**/api/v1/learning_goals**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningGoals),
      });
    });

    await page.route('**/api/v1/learning_profiles**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningProfiles),
      });
    });

    await page.route('**/api/v1/student_events**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    });

    await page.route('**/api/v1/activities**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    });

    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    // Wait for React to render
    await page.waitForTimeout(1000);

    // Should show dashboard - wait with longer timeout
    await expect(page.locator('h1')).toContainText('Learning Dashboard', { timeout: 15000 });

    // Reload and verify still authenticated
    await page.reload();
    await page.waitForLoadState('networkidle');

    // Wait for content to render after reload
    await page.waitForTimeout(1000);
    await expect(page.locator('h1')).toContainText('Learning Dashboard', { timeout: 15000 });
  });
});
