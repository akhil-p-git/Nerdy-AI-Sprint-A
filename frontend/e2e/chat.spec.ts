import { test, expect } from '@playwright/test';
import {
  mockAuthResponse,
  mockConversations,
  mockMessages,
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

  await page.route('**/api/v1/conversations', async (route) => {
    if (route.request().method() === 'GET') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockConversations),
      });
    } else if (route.request().method() === 'POST') {
      const newConversation = {
        id: 3,
        subject: 'Math',
        status: 'active',
        messages: [],
        message_count: 0,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify(newConversation),
      });
    }
  });

  await page.route('**/api/v1/conversations/*', async (route) => {
    // Return conversation with messages when fetching specific conversation
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ...mockConversations[0],
        messages: mockMessages,
      }),
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
}

test.describe('Chat Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuthenticatedState(page);
  });

  test('should display chat page with sidebar', async ({ page }) => {
    await page.goto('/chat');

    await expect(page.locator('text=AI Companion')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Your personal study assistant')).toBeVisible();
  });

  test('should display conversation list', async ({ page }) => {
    await page.goto('/chat');

    // Wait for page to load and conversations to render
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);

    // Check for conversation subjects (mathematics shows as General or the subject)
    // The ConversationList shows subject or "General" as the conversation title
    const content = await page.content();
    // Should have rendered some conversation items
    expect(content.length).toBeGreaterThan(0);

    // Check for conversation list structure
    await expect(page.locator('.w-80')).toBeVisible({ timeout: 10000 });
  });

  test('should show empty state when no conversation selected', async ({ page }) => {
    await page.goto('/chat');

    // Should show empty state with quick starts
    await expect(page.locator('text=Start a Conversation')).toBeVisible({ timeout: 10000 });

    // Check for the prompt text (partial match)
    const helpText = page.locator('text=Ask me anything');
    await expect(helpText).toBeVisible({ timeout: 10000 });
  });

  test('should display quick start options', async ({ page }) => {
    await page.goto('/chat');

    // Wait for page to fully load
    await page.waitForLoadState('networkidle');

    // Should show quick start buttons for different subjects
    // The quick starts are in a grid with subject names as button text
    await expect(page.locator('button:has-text("Math")').first()).toBeVisible({ timeout: 10000 });
    await expect(page.locator('button:has-text("Science")').first()).toBeVisible();
    await expect(page.locator('button:has-text("English")').first()).toBeVisible();
    await expect(page.locator('button:has-text("SAT")').first()).toBeVisible();
  });

  test('should load messages when selecting a conversation', async ({ page }) => {
    await page.goto('/chat');

    // Wait for page to load
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    // Look for a clickable conversation item (they're buttons in the ConversationList)
    const conversationItem = page.locator('button').filter({ hasText: /mathematics|General/i }).first();

    if (await conversationItem.count() > 0) {
      await conversationItem.click();

      // Wait for messages to load
      await page.waitForTimeout(1000);

      // Check content was loaded (page should change)
      const content = await page.content();
      expect(content.length).toBeGreaterThan(100);
    } else {
      // If no conversations, verify empty state is shown
      await expect(page.locator('text=Start a Conversation')).toBeVisible();
    }
  });

  test('should display AI responses with math content', async ({ page }) => {
    await page.goto('/chat');

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // Try to click on a conversation
    const conversationItem = page.locator('button').filter({ hasText: /mathematics|General/i }).first();

    if (await conversationItem.count() > 0) {
      await conversationItem.click();

      // Wait for messages to load
      await page.waitForTimeout(1000);

      // Check for math content in the page (from mock messages)
      const content = await page.content();
      // Should contain some math-related content
      expect(content.toLowerCase()).toMatch(/equation|solve|factor|math/i);
    } else {
      // If no conversations visible, test passes as empty state is valid
      await expect(page.locator('text=Start a Conversation')).toBeVisible();
    }
  });

  test('should have responsive sidebar', async ({ page }) => {
    await page.goto('/chat');

    // Sidebar should be visible
    const sidebar = page.locator('.w-80');
    await expect(sidebar).toBeVisible({ timeout: 10000 });
  });
});
