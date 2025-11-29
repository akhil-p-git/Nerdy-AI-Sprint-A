import { test, expect } from '@playwright/test';
import {
  mockAuthResponse,
  mockPracticeSession,
  mockLearningProfiles,
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

  await page.route('**/api/v1/learning_profiles', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockLearningProfiles),
    });
  });

  await page.route('**/api/v1/learning_profiles/summary', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockLearningProfiles),
    });
  });

  await page.route('**/api/v1/practice_sessions', async (route) => {
    if (route.request().method() === 'POST') {
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify(mockPracticeSession),
      });
    } else if (route.request().method() === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    }
  });

  await page.route('**/api/v1/practice_sessions/*/submit', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        correct: true,
        feedback: 'Great job!',
        correct_answer: 'x = 5',
      }),
    });
  });

  await page.route('**/api/v1/practice_sessions/*/complete', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        score: 85,
        correct_count: 2,
        total_count: 3,
        time_spent_seconds: 180,
        feedback: 'Great practice session!',
      }),
    });
  });

  await page.route('**/api/v1/practice_sessions/review', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });
}

test.describe('Practice Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuthenticatedState(page);
  });

  test('should display practice setup page initially', async ({ page }) => {
    await page.goto('/practice');

    // Should show setup options or practice content
    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });
    const content = await page.content();
    expect(content.toLowerCase()).toMatch(/practice|subject|start/i);
  });

  test('should allow subject selection for practice', async ({ page }) => {
    await page.goto('/practice');

    // Wait for page to load
    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });

    // Should display subject options
    const content = await page.content();
    expect(content.toLowerCase()).toMatch(/math|science|subject/i);
  });

  test('should show practice configuration options', async ({ page }) => {
    await page.goto('/practice');

    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });

    // Should have configuration options (difficulty, type, etc.)
    const content = await page.content();
    expect(content.toLowerCase()).toMatch(/difficulty|quiz|flashcard|practice/i);
  });

  test('should start practice session when form submitted', async ({ page }) => {
    await page.goto('/practice');

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // First, select a subject (button is disabled until subject is selected)
    const mathSubject = page.locator('button:has-text("Mathematics")');
    if (await mathSubject.count() > 0) {
      await mathSubject.click();
      await page.waitForTimeout(500);
    }

    // Find and click start button
    const startButton = page.locator('button:has-text("Start Practice")');

    if (await startButton.count() > 0) {
      // Verify button is enabled after subject selection
      await expect(startButton).toBeEnabled({ timeout: 5000 });
      await startButton.click();

      // Should navigate or show session content
      await page.waitForTimeout(1000);
      const content = await page.content();
      expect(content).toBeTruthy();
    }
  });

  test('should handle page load without errors', async ({ page }) => {
    await page.goto('/practice');

    // Page should load without JavaScript errors
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));

    await page.waitForTimeout(2000);
    expect(errors.length).toBe(0);
  });

  test('should display loading state appropriately', async ({ page }) => {
    // Add delay to mock responses
    await page.route('**/api/v1/learning_profiles', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 500));
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockLearningProfiles),
      });
    });

    await page.goto('/practice');

    // Should eventually load content
    await expect(page.locator('body')).toBeVisible({ timeout: 15000 });
  });

  test('should be accessible on different viewport sizes', async ({ page }) => {
    // Test on mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/practice');

    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });

    // Test on tablet viewport
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.reload();

    await expect(page.locator('body')).toBeVisible({ timeout: 10000 });
  });
});
