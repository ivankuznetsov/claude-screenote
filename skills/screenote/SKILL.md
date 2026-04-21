---
name: screenote
description: Capture a page at desktop/tablet/mobile viewports and upload to Screenote for human annotation
user_invocable: true
argument: "[desktop|tablet|mobile] [url-or-description]"
---

# Screenote — Visual Feedback Loop

You are executing the Screenote skill. This connects Claude Code to Screenote for visual feedback: screenshot a page at three viewports by default (desktop, tablet, mobile) and upload them as one logical Screenshot that the human can annotate per-viewport.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `feedback` → tell the user: "Feedback has moved to its own command. Run `/feedback` (or `/claude-screenote:feedback`) instead." Stop.
- If the argument starts with `desktop`, `tablet`, or `mobile` → **single-viewport mode**: capture only that viewport (strip the keyword from the argument; the rest is the URL/description).
- Otherwise → **multi-viewport mode (default)**: capture all three viewports (desktop + tablet + mobile) as one Screenshot.

## Viewport Dimensions

Fixed defaults (match Screenote server's canonical set):

| Viewport | Dimensions | Notes |
|---|---|---|
| `desktop` | **1280 × 800** | Playwright's default desktop |
| `tablet`  | **768 × 1024** | iPad mini |
| `mobile`  | **390 × 844** | iPhone 14 |

---

## Project Cache

Call `list_projects` to verify the MCP connection and get the current project list. If the call fails with an auth error, tell the user to authorize the Screenote MCP server and stop.

Then check for a cached project selection:

1. Try to read `.claude/screenote-cache.json` (relative to cwd). If it exists and contains valid JSON with `project_id` and `project_name`, AND that `project_id` appears in the `list_projects` response, use that project and skip the "Pick a Project" step. Do not announce the cached selection.
2. If the file is missing, invalid, or the `project_id` is not in the `list_projects` response (stale cache), delete the cache file if it exists and proceed with the normal "Pick a Project" step below. After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.claude/screenote-cache.json` (create the `.claude/` directory if needed).

---

## Capture Mode

The user provided a URL or page description. Your job: screenshot it at the chosen viewport(s), upload to Screenote, return the annotation URL.

### Step 1: Pick a Project

**Check the Project Cache first** (see Project Cache section above). The `list_projects` call has already been made there. If the cache provides a valid project, skip to Step 2.

If no cache hit, determine the **local project name** from the current working directory (e.g., the repo/folder name). Use the project list already fetched in the Project Cache step. Always refer to projects by **name** — use `id` only internally for API calls.

**Matching logic:**
- If a Screenote project name matches the local project name (case-insensitive), use it automatically
- If no match is found (even if there's only one project), ask the user: list existing project names and offer to create a new one matching the local project name via the `create_project` MCP tool

After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.claude/screenote-cache.json`.

### Step 2: Resolve the URL

- If the argument looks like a full URL (starts with `http`), use it directly
- If it looks like a relative path (e.g., `/login`, `dashboard`), prepend `http://localhost:3000/`
- If it's a description (e.g., "login page"), figure out the URL from context (check routes, running servers, etc.)

### Step 3: Request Upload URLs

Decide which viewports to capture:

- **Multi-viewport mode (default)**: `[desktop, tablet, mobile]`
- **Single-viewport mode**: just the one the user named (`[desktop]`, `[tablet]`, or `[mobile]`)

Call the `create_multi_viewport_screenshot` MCP tool once:

```
Tool: create_multi_viewport_screenshot
Arguments:
  project_id: <from Step 1>
  page_name: <URL path, e.g. "/login", "/settings/profile">
  title: <version label — use the current date (e.g., "2025-06-15") or a short descriptor>
  viewports:
    - { viewport: "desktop", mime_type: "image/png" }
    - { viewport: "tablet",  mime_type: "image/png" }
    - { viewport: "mobile",  mime_type: "image/png" }
```

(Include only the viewports you decided on — single-viewport mode sends one array entry.)

The response returns:

```
{
  "screenshot_id": 123,
  "page_id": 45,
  "annotate_url": "https://screenote.ai/screenshots/123",
  "uploads": [
    { "viewport": "desktop", "upload_url": "https://...", "token": "..." },
    { "viewport": "tablet",  "upload_url": "...",        "token": "..." },
    { "viewport": "mobile",  "upload_url": "...",        "token": "..." }
  ]
}
```

**Important:** capture screenshots *after* requesting upload URLs so tokens don't expire mid-capture (they live for 5 minutes).

### Step 4: Capture and Upload Each Viewport

For each entry in the `uploads` array, in order:

1. **Resize** the browser: `browser_resize` to the dimensions from the Viewport Dimensions table above
2. **Navigate**: `browser_navigate` to the URL (fresh navigate per viewport — safer for SPAs than resize-only since many frameworks read viewport at mount time)
3. **Wait**: `browser_wait_for` for dynamic content (loading spinners, skeleton screens) to settle
4. **Screenshot**: `browser_take_screenshot` with `filename` set to `/tmp/screenote-{viewport}.png` and `type` set to `png`
5. **Upload**: use curl to PUT the binary to the signed `upload_url` — the image bytes never enter the LLM context:

```bash
curl -X PUT -H 'Content-Type: image/png' --data-binary @/tmp/screenote-{viewport}.png '<upload_url>'
```

6. **Track progress**: print `[desktop] uploaded`, `[tablet] uploaded`, `[mobile] uploaded`

Do NOT parallelize captures — Playwright MCP shares a single browser context. Serial capture is ~3× slower than single-viewport but reliable.

### Step 5: Report to User

Tell the user:
- The viewports that were uploaded (e.g. "Uploaded desktop / tablet / mobile")
- Say "Uploaded to **<project_name>**" and provide the **annotate_url** so they can open it in the browser and add annotations
- Mention they can switch between viewports in Screenote using the device-icon toolbar
- Tell them to run `/feedback` when they're done annotating

Clean up the temp files:

```bash
rm -f /tmp/screenote-desktop.png /tmp/screenote-tablet.png /tmp/screenote-mobile.png
```
