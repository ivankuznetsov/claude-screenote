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

## Project Cache

Before calling `list_projects`, check for a cached project selection:

1. Try to read `.claude/screenote-cache.json` (relative to cwd). If the file does not exist, skip to step 2. If it exists and contains valid JSON with `project_id` and `project_name`, use that project and skip the "Pick a Project" step. Print: "Using cached Screenote project: **\<name\>** (delete `.claude/screenote-cache.json` to switch)"
2. If the file is missing or invalid, proceed with the normal "Pick a Project" step below. After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.claude/screenote-cache.json` (create the `.claude/` directory if needed).
3. If any tool call that uses the cached `project_id` returns a response containing `"error": "forbidden"` or `"error": "not_found"`, the cache is stale. Delete the cache file and re-run the "Pick a Project" step.

---

## Step 1: Pick a Project

**Check the Project Cache first** (see Project Cache section). If the cache provides a valid project, skip to Step 2.

If no cache, determine the **local project name** from the current working directory (e.g., the repo/folder name).

Call the `list_projects` MCP tool to get the user's Screenote projects. Each project has an `id` and a `name`. Always refer to projects by **name** — use `id` only internally for API calls.

**Matching logic:**
- If a Screenote project name matches the local project name (case-insensitive), use it automatically
- If no match is found (even if there's only one project), ask the user: list existing project names and offer to create a new one matching the local project name via the `create_project` MCP tool

After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.claude/screenote-cache.json`.

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
- If it looks like a relative path, prepend `http://localhost:3000`
- If it's a description or empty, default to `http://localhost:3000`

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
- Search for `app.get(`, `app.post(`, `router.get(`, `router.post(` patterns
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

After static analysis, optionally navigate to the base URL and extract links:

1. Navigate to `base_url` with `browser_navigate`
2. Use `browser_snapshot` to get the page's accessibility tree
3. Extract all internal links (same-origin `<a href>` values)
4. Add any new routes not found in static analysis

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

## Step 5: Handle Authentication

Some pages require login. Detect and handle this:

### Detection
- Ask the user: "Does this app require authentication? If so, how should I log in?"
- Common options:
  - **Form login**: Navigate to login page, fill in credentials (user provides username/password)
  - **Already logged in**: If the browser session already has auth cookies/tokens
  - **No auth needed**: All pages are public

### Login Flow (if needed)

1. Navigate to the login page using `browser_navigate`
2. Use `browser_snapshot` to see the form fields
3. Fill in credentials using `browser_type` for each field
4. Submit the form using `browser_click`
5. Wait for redirect/confirmation using `browser_wait_for`
6. Verify login succeeded by checking the resulting page

**Important:** Perform login **once** before starting the screenshot loop. The browser session will maintain cookies/tokens for subsequent page visits.

### Route Ordering

Order routes so that:
1. **Public pages first** (login, signup, landing pages)
2. **Login step** (if authentication is needed)
3. **Authenticated pages** (dashboard, settings, admin, etc.)

---

## Step 6: Set Viewport

Resize the browser to the correct viewport:

- **Desktop** (default): `browser_resize` to **1440 x 900**
- **Mobile** (when `mobile` keyword was used): `browser_resize` to **393 x 852** (iPhone 15)

---

## Step 7: Screenshot Each Page

Loop through the route list and capture each page.

For each route:

1. **Navigate**: `browser_navigate` to `<base_url><route_path>`
2. **Wait**: Use `browser_wait_for` if the page has dynamic content (check for loading spinners, skeleton screens, etc.)
3. **Screenshot**: `browser_take_screenshot` with `filename` set to `/tmp/screenote-snapshot-<index>.png` and `type` set to `png`
4. **Upload**: Call `create_screenshot_upload` MCP tool:
   ```
   Tool: create_screenshot_upload
   Arguments:
     project_id: <from step 1>
     title: "<snapshot_label> — <route_path>"
     mime_type: "image/png"
   ```
   - The title format is: `App Snapshot — 2025-06-15 — a1b2c3d — /dashboard`
   - Append `(mobile)` if mobile viewport was used
5. **Upload file**:
   ```bash
   curl -X PUT -H 'Content-Type: image/png' --data-binary @/tmp/screenote-snapshot-<index>.png '<upload_url>'
   ```
6. **Clean up**:
   ```bash
   rm -f /tmp/screenote-snapshot-<index>.png
   ```
7. **Track progress**: Print `[3/12] /dashboard — uploaded` after each successful upload

### Error Handling

- If a page returns a 404 or error, capture it anyway (the error state is useful for review) but note it in the summary
- If a page requires auth and you're not logged in (redirects to login), note it and suggest the user provide credentials
- If navigation times out, skip the page and note it in the summary

---

## Step 8: Summary Report

After all pages are captured, present a summary:

```
App Snapshot Complete

Date: 2025-06-15
Commit: a1b2c3d — "Fix header alignment"
Viewport: Desktop (1440x900)
Pages captured: 11/12

Uploaded screenshots:
 1. App Snapshot — 2025-06-15 — a1b2c3d — /
 2. App Snapshot — 2025-06-15 — a1b2c3d — /login
 3. App Snapshot — 2025-06-15 — a1b2c3d — /signup
 4. App Snapshot — 2025-06-15 — a1b2c3d — /dashboard
 5. App Snapshot — 2025-06-15 — a1b2c3d — /dashboard/analytics
 6. App Snapshot — 2025-06-15 — a1b2c3d — /settings
 7. App Snapshot — 2025-06-15 — a1b2c3d — /settings/profile
 8. App Snapshot — 2025-06-15 — a1b2c3d — /settings/billing
 9. App Snapshot — 2025-06-15 — a1b2c3d — /users
10. App Snapshot — 2025-06-15 — a1b2c3d — /admin
11. App Snapshot — 2025-06-15 — a1b2c3d — /admin/settings

Skipped:
 - /users/:id (dynamic route — no sample value provided)

Open Screenote to review and annotate the snapshots.
Run /screenote feedback when ready.
```

---

## Key Differences from /screenote

| Feature | `/screenote` | `/snapshot` |
|---|---|---|
| Pages | Single page | All discovered pages |
| Route discovery | User provides URL | Agent explores codebase |
| Auth handling | Not handled | Login flow before capturing |
| Metadata | Simple title | Date + commit hash in every title |
| Output | One screenshot + annotate link | Batch upload + summary report |
