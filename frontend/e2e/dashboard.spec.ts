import { test, expect } from '@playwright/test';
import {
  mockAuthResponse,
  mockStats,
  mockLearningGoals,
  mockLearningProfiles,
  mockActivities,
} from './fixtures/mock-data';

// Helper function to set up authenticated state and API mocks
async function setupAuthenticatedState(page: import('@playwright/test').Page) {
  // Set up authentication tokens
  await page.addInitScript(() => {
    localStorage.setItem('token', 'mock-jwt-token-12345');
    localStorage.setItem('refreshToken', 'mock-refresh-token-67890');
  });

  // Mock all API endpoints
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

  await page.route('**/api/v1/stats/weekly', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ weekly_stats: [] }),
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

  await page.route('**/api/v1/activities', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockActivities),
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

test.describe('Dashboard Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuthenticatedState(page);
  });

  test('should display dashboard with correct heading', async ({ page }) => {
    await page.goto('/dashboard');

    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Track your progress')).toBeVisible();
  });

  test('should display active goals section', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for dashboard to fully load
    await page.waitForLoadState('networkidle');

    // Use heading role to be more specific (avoid matching the stat card label)
    await expect(page.getByRole('heading', { name: 'Active Goals' })).toBeVisible({ timeout: 10000 });

    // Check that active goals are displayed (with longer timeout for data loading)
    await expect(page.locator('text=Master Quadratic Equations')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Learn Photosynthesis')).toBeVisible({ timeout: 10000 });
  });

  test('should display completed goals section', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for dashboard to fully load
    await page.waitForLoadState('networkidle');

    // Check for "Completed (X)" header - the number comes from completed goals count
    await expect(page.locator('text=/Completed \\(\\d+\\)/')).toBeVisible({ timeout: 10000 });

    // Should show completed goal - use getByText with exact match to avoid matching congratulations modal
    await expect(page.getByText('Complete Algebra Unit', { exact: true })).toBeVisible({ timeout: 10000 });
  });

  test('should display subject progress section', async ({ page }) => {
    await page.goto('/dashboard');

    await expect(page.locator('text=Subject Progress')).toBeVisible({ timeout: 10000 });

    // Check that subjects are displayed
    await expect(page.locator('text=Math').first()).toBeVisible();
    await expect(page.locator('text=Science').first()).toBeVisible();
  });

  test('should display progress stats', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for dashboard to fully load
    await page.waitForLoadState('networkidle');
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 10000 });

    // Wait for stats to render
    await page.waitForTimeout(500);

    // Stats should be visible - check for specific stat values
    const content = await page.content();
    // Check for stats values from mockStats (total_practice_problems: 150)
    expect(content).toContain('150');
    // Also verify other stats appear
    expect(content).toContain('Problems Solved');
  });

  test('should show add goal button', async ({ page }) => {
    await page.goto('/dashboard');

    await expect(page.locator('text=Add Goal')).toBeVisible({ timeout: 10000 });
  });

  test('should display empty state when no active goals', async ({ page }) => {
    // Override to return no active goals
    await page.route('**/api/v1/learning_goals', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    });

    await page.goto('/dashboard');

    // Should show empty state message
    await expect(page.locator('text=No active goals')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Create Your First Goal')).toBeVisible();
  });

  test('should handle loading state', async ({ page }) => {
    // Add a delay to API responses to test loading state
    await page.route('**/api/v1/learning_goals', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 500));
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningGoals),
      });
    });

    await page.goto('/dashboard');

    // Should eventually show content
    await expect(page.locator('text=Learning Dashboard')).toBeVisible({ timeout: 15000 });
  });

  test('should display goal progress percentage', async ({ page }) => {
    await page.goto('/dashboard');

    // Wait for dashboard to fully load
    await page.waitForLoadState('networkidle');

    // Wait for goals to load
    await expect(page.locator('text=Master Quadratic Equations')).toBeVisible({ timeout: 10000 });

    // Wait for CircularProgress to render
    await page.waitForTimeout(500);

    // Check that progress is shown - CircularProgress shows "{percentage}%"
    const content = await page.content();
    // The first goal has progress_percentage: 45, shown as "45%"
    expect(content).toContain('45%');
  });
});
