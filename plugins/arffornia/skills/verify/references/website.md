# Website (Laravel 12) with Playwright

Layout (from the e2e PR on Arffornia_Website): `e2e/playwright.config.ts` starts the app with
`e2e/serve.sh`: a fresh SQLite database `database/e2e.sqlite`, the deterministic
`Database\Seeders\E2ESeeder`, and `php artisan serve` on port 8001.

```bash
npm ci && npm run build                          # frontend assets, from the repo root
npm ci --prefix e2e
npx --prefix e2e playwright install chromium     # once per machine
cd e2e && npx playwright test                    # all journeys
npx playwright test tests/shop.spec.ts --trace on --reporter=list
E2E_BASE_URL=http://127.0.0.1:8080 npx playwright test   # against an already running instance
```

Writing a check:
- Use roles and text, not CSS: `page.getByRole('button', { name: 'Buy' })`.
- Both languages for player text: run the journey with the locale switch (`/lang/fr` or the
  session key the site uses) and assert the French string.
- Negative checks: a 403 for a non-admin (`expect(response.status()).toBe(403)`), no stack
  trace on a forced 500 (`expect(page.locator('body')).not.toContainText('Stack trace')`).
- Screenshots: `await page.screenshot({ path: '../build/verify/<slug>/shop-fr.png', fullPage: true })`.
- No real Microsoft login: use the testing-only login route when it exists (issue #67); until
  then, verify authenticated pages with a Feature test (`actingAs`) and say so.

Evidence: `N passed (Xs)` line, test names, screenshot paths, `playwright-report/` if kept.
