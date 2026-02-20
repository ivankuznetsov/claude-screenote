---
name: snapshot
description: Take a full app snapshot — discover all routes, screenshot every page (including authenticated ones), and upload to Screenote with date and commit metadata
user_invocable: true
argument: "[mobile] [base-url or description]"
---

# Snapshot — Full App Visual Snapshot

You are executing the Snapshot skill. This captures a complete visual snapshot of an application: discover all routes, screenshot every page (including ones behind authentication), and upload them to Screenote as a batch. Each screenshot is tagged with the current date and the last git commit hash.

This is separate from the single-page `/screenote` command. Use `/snapshot` when you need a full picture of the entire app.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `mobile` → use **mobile viewport** (strip `mobile` from the argument, the rest is the base URL/description)
- Otherwise → use **desktop viewport**

---

## Step 1: Pick a Project

Follow the **Project Cache** and **Pick a Project** procedure from the `/screenote` skill (`skills/screenote/SKILL.md`). The logic is identical: check `.claude/screenote-cache.json`, match by local project name, or prompt the user. Refer to that skill for the full steps.

---

## Step 2: Collect Metadata

Gather the date and last commit information. Run:

```bash
echo "DATE=$(date +%Y-%m-%d)" && git log -1 --format="COMMIT=%h %s"
```

Parse the output to extract:
- `snapshot_date` — e.g., `2025-06-15`
- `commit_short` — short hash, e.g., `a1b2c3d`
- `commit_message` — first line of commit message

Compose a **snapshot label**:
```
App Snapshot — <snapshot_date> — <commit_short>
```

This label will be used as a prefix in every screenshot title.

---

## Step 3: Resolve the Base URL

The user provides either a base URL or a description of the app.

- If the argument looks like a full URL (starts with `http`), use it as the base URL
- If it looks like a relative path, prepend the detected base URL (see below)
- If it's a description or empty, detect the base URL from the project

**Port detection:** Do not assume `localhost:3000`. Infer the port from the project's framework:
- Check for a running dev server first (e.g., `lsof -i -P -n | grep LISTEN` or similar)
- If nothing is running, infer from project files: `package.json` scripts (Next.js/Vite/CRA → 3000-5173), `manage.py` (Django → 8000), `config/routes.rb` (Rails → 3000), `mix.exs` (Phoenix → 4000), `go.mod` (Go → 8080)
- If detection fails, ask the user for the base URL instead of guessing

Store this as `base_url` (no trailing slash).

---

## Step 4: Discover All Routes

This is the core discovery step. Use **multiple strategies** to build a comprehensive route list.

### Strategy A: Static Analysis of the Codebase

Search the local project files for route definitions. Look for common patterns depending on the framework:

**React Router / React:**
- Search for `<Route`, `path=`, `createBrowserRouter`, `createRoutesFromElements` in `*.tsx`, `*.jsx`, `*.ts`, `*.js` files
- Check for file-based routing in `app/routes/`, `src/pages/`, `src/app/` directories (Next.js, Remix, etc.)

**Next.js:**
- Scan `pages/` or `app/` directory structure — each file/folder is a route
- `page.tsx`, `page.jsx`, `page.js` files define routes in the App Router

**Vue Router:**
- Search for `routes:` arrays, `path:` definitions in router config files

**Angular:**
- Search for `RouterModule.forRoot`, `Routes` arrays

**Express / Backend:**
- Search for `app.get(`, `router.get(` patterns only — POST/PUT/DELETE endpoints are API handlers, not navigable pages
- Look for route definition files

**Django:**
- Search for `urlpatterns`, `path(`, `re_path(` in `urls.py` files

**Rails:**
- Check `config/routes.rb`

**General:**
- Search for any file named `routes.*`, `router.*`, `urls.*`
- Look at the project's README or docs for route listings
- Check for sitemap files

Build a list of route paths (e.g., `/`, `/login`, `/dashboard`, `/settings`, `/users/:id`).

### Strategy B: Runtime Discovery (supplement)

After static analysis, optionally navigate to the base URL and extract links. **Set the viewport first** (see Step 5) before any browser interaction:

1. Set viewport via `browser_resize` (desktop or mobile, per Mode Detection)
2. Navigate to `base_url` with `browser_navigate`
3. Use `browser_snapshot` to get the page's accessibility tree
4. Extract all internal links (same-origin `<a href>` values)
5. Add any new routes not found in static analysis

### Handling Dynamic Routes

For routes with parameters (e.g., `/users/:id`, `/posts/[slug]`):
- Note them in the route list but mark them as **dynamic**
- Ask the user if they want to provide sample values, or skip dynamic routes
- If the user provides values, substitute them; otherwise skip those routes

### Present the Route List

Show the user the discovered routes in a numbered list:

```
Discovered 12 routes:

 1. / (home)
 2. /login
 3. /signup
 4. /dashboard
 5. /dashboard/analytics
 6. /settings
 7. /settings/profile
 8. /settings/billing
 9. /users (list)
10. /users/:id (dynamic — will skip unless sample ID provided)
11. /admin
12. /admin/settings
```

Ask the user:
- **Confirm** the list, or add/remove routes
- Provide sample values for any dynamic routes they want included
- Identify which routes require **authentication** (or let the agent discover this in the next step)

---

## Step 5: Ensure Viewport Is Set

If you already set the viewport during Strategy B (runtime discovery), skip this step. Otherwise, resize the browser now — before authentication or any screenshots:

- **Desktop** (default): `browser_resize` to **1440 x 900**
- **Mobile** (when `mobile` keyword was used): `browser_resize` to **393 x 852** (iPhone 15)

---

## Step 6: Handle Authentication

Some pages require login. Detect and handle this:

### Detection
- Ask the user: "Does this app require authentication? If so, how should I log in?"
- Common options:
  - **Form login**: Navigate to login page, fill in credentials (user provides username/password)
  - **Already logged in**: If the browser session already has auth cookies/tokens
  - **No auth needed**: All pages are public

**Security note:** Credentials provided for form login will be visible in the conversation context. For sensitive environments, prefer one of these alternatives:
- Log in manually in the browser before running `/snapshot` (the session cookies persist)
- Set credentials via environment variables and reference them in the login flow
- Use a test/staging account with limited permissions

### Login Flow (if needed)

1. Navigate to the login page using `browser_navigate`
2. Use `browser_snapshot` to see the form fields
3. Fill in credentials using `browser_type` for each field
4. Submit the form using `browser_click`
5. Wait for redirect/confirmation using `browser_wait_for`
6. Verify login succeeded by checking the resulting page

**Important:** Perform login **once**. The browser session will maintain cookies/tokens for subsequent page visits.

### Route Ordering and Login Timing

Split the screenshot loop into two phases so public pages are captured in their unauthenticated state:

1. **Phase 1 — Public pages** (login form, signup form, landing pages): screenshot these **before** logging in
2. **Login step**: perform the login flow (if authentication is needed)
3. **Phase 2 — Authenticated pages** (dashboard, settings, admin, etc.): screenshot these **after** logging in

---

## Step 7: Screenshot Each Page

### Setup

Create a unique temp directory to avoid collisions with concurrent runs:

```bash
SNAP_DIR=$(mktemp -d /tmp/screenote-snapshot-XXXXXX)
```

### Capture Loop

Loop through the route list and capture each page.

For each route:

1. **Navigate**: `browser_navigate` to `<base_url><route_path>`
2. **Wait**: Use `browser_wait_for` if the page has dynamic content (check for loading spinners, skeleton screens, etc.)
3. **Screenshot**: `browser_take_screenshot` with `filename` set to `<SNAP_DIR>/<index>.png` and `type` set to `png`
4. **Upload**: Call `create_screenshot_upload` MCP tool:
   ```
   Tool: create_screenshot_upload
   Arguments:
     project_id: <from step 1>
     page_name: "<route_path>" — e.g., "/dashboard", "/settings/profile". Append " (mobile)" if mobile viewport was used.
     title: "<snapshot_label>" — e.g., "App Snapshot — 2025-06-15 — a1b2c3d"
     mime_type: "image/png"
   ```
   - `page_name` groups all snapshots of the same route as versions of that page
   - `title` is the snapshot label (same for all pages in one run) — it distinguishes this snapshot run from previous ones
5. **Upload file**:
   ```bash
   curl -X PUT -H 'Content-Type: image/png' --data-binary @<SNAP_DIR>/<index>.png '<upload_url>'
   ```
6. **Track progress**: Print `[3/12] /dashboard — uploaded` after each successful upload

### Cleanup

After the loop completes (whether successful or not), remove the temp directory:

```bash
rm -rf <SNAP_DIR>
```

### Error Handling

- If a page returns a 404 or error, capture it anyway (the error state is useful for review) but note it in the summary
- If a page requires auth and you're not logged in (redirects to login), note it and suggest the user provide credentials
- If navigation times out, skip the page and note it in the summary
- **If the process fails mid-batch** (API error, browser crash, network issue): report which pages were successfully uploaded versus which remain, clean up the temp directory, and offer to resume from the last failed page

---

## Step 8: Summary Report

After all pages are captured, present a page-grouped summary:

```
App Snapshot Complete

Date: 2025-06-15
Commit: a1b2c3d — "Fix header alignment"
Viewport: Desktop (1440x900)
Snapshot label: App Snapshot — 2025-06-15 — a1b2c3d
Pages captured: 11/12

Uploaded pages:
 1. /                         — uploaded (new page)
 2. /login                    — uploaded (new version)
 3. /signup                   — uploaded (new page)
 4. /dashboard                — uploaded (new version)
 5. /dashboard/analytics      — uploaded (new page)
 6. /settings                 — uploaded (new version)
 7. /settings/profile         — uploaded (new page)
 8. /settings/billing         — uploaded (new page)
 9. /users                    — uploaded (new page)
10. /admin                    — uploaded (new version)
11. /admin/settings           — uploaded (new page)

Skipped:
 - /users/:id (dynamic route — no sample value provided)

Each route is stored as a page in Screenote. Repeated snapshots of the
same route appear as versions, so you can compare changes over time.

Open Screenote to review and annotate the snapshots.
Run /screenote feedback when ready.
```

Note: "new page" means this is the first snapshot for that route; "new version" means a previous snapshot already exists for that route.

---

## Key Differences from /screenote

| Feature | `/screenote` | `/snapshot` |
|---|---|---|
| Pages | Single page | All discovered pages |
| Route discovery | User provides URL | Agent explores codebase |
| Auth handling | Not handled | Login flow before capturing |
| Metadata | Simple title | Date + commit hash in every title |
| Output | One screenshot + annotate link | Batch upload + summary report |
