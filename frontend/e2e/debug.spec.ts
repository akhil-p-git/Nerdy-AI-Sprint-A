import { test, expect } from '@playwright/test';

test('debug - check page loads', async ({ page }) => {
  // Capture console logs and errors
  page.on('console', msg => console.log('CONSOLE:', msg.type(), msg.text()));
  page.on('pageerror', err => console.log('PAGE ERROR:', err.message));

  // Set up route for API calls
  await page.route('http://localhost:3000/**', async (route) => {
    console.log('INTERCEPTED:', route.request().url());
    if (route.request().url().includes('/auth/me')) {
      await route.fulfill({ status: 401 });
    } else {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({}),
      });
    }
  });

  console.log('Navigating to login...');
  await page.goto('http://localhost:3005/login');

  // Wait longer for React to render
  console.log('Waiting for page to render...');
  await page.waitForTimeout(5000);

  // Get DOM info
  const rootElement = await page.locator('#root').innerHTML();
  console.log('ROOT innerHTML length:', rootElement.length);
  console.log('ROOT innerHTML:', rootElement.substring(0, 3000));

  // Check for any visible elements
  const bodyText = await page.locator('body').innerText();
  console.log('BODY TEXT:', bodyText);

  // Check for any divs
  const divCount = await page.locator('div').count();
  console.log('DIV COUNT:', divCount);
});
