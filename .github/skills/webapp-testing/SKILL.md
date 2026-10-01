---
name: webapp-testing
description: Verify local web applications with Playwright. Use for browser regression checks, frontend interactions, UI failures, screenshots, and browser console diagnostics.
metadata:
  author: Anthropic
  maintainer: wzlwit
  version: null
---

# Web Application Testing

Adapted from Anthropic's webapp-testing skill (`https://github.com/anthropics/skills`,
`skills/webapp-testing`), Apache-2.0; see `LICENSE.txt`. The original is in the Original section
below; its server helper and examples are in this skill's folder. Where it differs, the SkillVault
rules above it win: reuse the project's tests and tools first, use the project's `.venv` for
Python, and wait for a specific element or response instead of network idle or fixed sleeps.

Check a specific user-visible workflow against observable expectations. Use the project's
existing browser tests or available Playwright tools before creating another test harness.

## Workflow

1. Identify the page, action, and expected outcome from the request and current code. Read
   the nearest test and the project's test commands; keep coverage within the requested scope.
2. Reuse an appropriate running local server, or start the documented development server on
   a free port. For static content, open the local HTML directly. Do not touch production.
3. Navigate and inspect the rendered page. Wait for the relevant element or response with a
   bounded timeout; avoid arbitrary sleeps and assuming that network-idle proves readiness.
4. Choose locators from the observed DOM, preferably accessible roles and names or existing
   test IDs. Exercise the workflow and assert visible state, navigation, or expected errors.
5. Capture screenshots and relevant console or request failures. Check desktop and mobile
   layouts when the changed behavior is responsive. Do not call a screenshot an assertion.
6. Add a focused regression to an existing test file when durable coverage is useful. Run
   that test and report its actual outcome. Stop processes and close browsers you started.

## Setup and Boundaries

- Reuse the existing Playwright language and tooling. When a standalone Python check is
  appropriate, use the project's `.venv` and its interpreter, not system Python or conda.
- Install missing browser dependencies only for the agreed test task. Installing this skill
  installs no Playwright runtime or browser binaries.
- Use test accounts and non-sensitive fixtures. Purchases, account deletion, and external
  submissions require separate authorization; never record credentials in test artifacts.
- Report URL or file tested, actions, assertions, failures, and evidence paths. Disclose any
  skipped browser execution; a passing catalog check does not prove a web app works.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/anthropics/skills skills/webapp-testing at 8a1541c4a3ffa5a20a5a91de0dcf3f0bab1d1ef4. Refresh replaces this section; put SkillVault changes outside it. -->

# Web Application Testing

To test local web applications, write native Python Playwright scripts.

**Helper Scripts Available**:
- `scripts/with_server.py` - Manages server lifecycle (supports multiple servers)

**Always run scripts with `--help` first** to see usage. DO NOT read the source until you try running the script first and find that a customized solution is abslutely necessary. These scripts can be very large and thus pollute your context window. They exist to be called directly as black-box scripts rather than ingested into your context window.

## Decision Tree: Choosing Your Approach

```
User task → Is it static HTML?
    ├─ Yes → Read HTML file directly to identify selectors
    │         ├─ Success → Write Playwright script using selectors
    │         └─ Fails/Incomplete → Treat as dynamic (below)
    │
    └─ No (dynamic webapp) → Is the server already running?
        ├─ No → Run: python scripts/with_server.py --help
        │        Then use the helper + write simplified Playwright script
        │
        └─ Yes → Reconnaissance-then-action:
            1. Navigate and wait for networkidle
            2. Take screenshot or inspect DOM
            3. Identify selectors from rendered state
            4. Execute actions with discovered selectors
```

## Example: Using with_server.py

To start a server, run `--help` first, then use the helper:

**Single server:**
```bash
python scripts/with_server.py --server "npm run dev" --port 5173 -- python your_automation.py
```

**Multiple servers (e.g., backend + frontend):**
```bash
python scripts/with_server.py \
  --server "cd backend && python server.py" --port 3000 \
  --server "cd frontend && npm run dev" --port 5173 \
  -- python your_automation.py
```

To create an automation script, include only Playwright logic (servers are managed automatically):
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True) # Always launch chromium in headless mode
    page = browser.new_page()
    page.goto('http://localhost:5173') # Server already running and ready
    page.wait_for_load_state('networkidle') # CRITICAL: Wait for JS to execute
    # ... your automation logic
    browser.close()
```

## Reconnaissance-Then-Action Pattern

1. **Inspect rendered DOM**:
   ```python
   page.screenshot(path='/tmp/inspect.png', full_page=True)
   content = page.content()
   page.locator('button').all()
   ```

2. **Identify selectors** from inspection results

3. **Execute actions** using discovered selectors

## Common Pitfall

❌ **Don't** inspect the DOM before waiting for `networkidle` on dynamic apps
✅ **Do** wait for `page.wait_for_load_state('networkidle')` before inspection

## Best Practices

- **Use bundled scripts as black boxes** - To accomplish a task, consider whether one of the scripts available in `scripts/` can help. These scripts handle common, complex workflows reliably without cluttering the context window. Use `--help` to see usage, then invoke directly. 
- Use `sync_playwright()` for synchronous scripts
- Always close the browser when done
- Use descriptive selectors: `text=`, `role=`, CSS selectors, or IDs
- Add appropriate waits: `page.wait_for_selector()` or `page.wait_for_timeout()`

## Reference Files

- **examples/** - Examples showing common patterns:
  - `element_discovery.py` - Discovering buttons, links, and inputs on a page
  - `static_html_automation.py` - Using file:// URLs for local HTML
  - `console_logging.py` - Capturing console logs during automation
<!-- upstream:end -->
