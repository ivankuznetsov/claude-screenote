---
name: screenote
description: Capture a page screenshot and upload to Screenote for human annotation
user_invocable: true
argument: "[mobile] [url-or-description]"
---

# Screenote — Visual Feedback Loop

You are executing the Screenote skill. This connects Claude Code to Screenote for visual feedback: screenshot a page, upload it for human annotation, then retrieve the feedback.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `feedback` → tell the user: "Feedback has moved to its own command. Run `/feedback` (or `/claude-screenote:feedback`) instead." Stop.
- If the argument starts with `mobile` → go to **Capture Mode** with **mobile viewport** (strip `mobile` from the argument, the rest is the URL/description)
- Otherwise → go to **Capture Mode** with **desktop viewport**

---

## Project Cache

Call `list_projects` to verify the MCP connection and get the current project list. If the call fails with an auth error, tell the user to authorize the Screenote MCP server and stop.

Then check for a cached project selection:

1. Try to read `.claude/screenote-cache.json` (relative to cwd). If it exists and contains valid JSON with `project_id` and `project_name`, AND that `project_id` appears in the `list_projects` response, use that project and skip the "Pick a Project" step. Do not announce the cached selection.
2. If the file is missing, invalid, or the `project_id` is not in the `list_projects` response (stale cache), delete the cache file if it exists and proceed with the normal "Pick a Project" step below. After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.claude/screenote-cache.json` (create the `.claude/` directory if needed).

---

## Capture Mode

The user provided a URL or page description. Your job: screenshot it, upload to Screenote, return the annotation URL.

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

### Step 3: Set Viewport and Take Screenshot

**Before navigating**, resize the browser to the correct viewport:

- **Desktop** (default): `browser_resize` to **1440 x 900**
- **Mobile** (when `mobile` keyword was used): `browser_resize` to **393 x 852** (iPhone 15)

Then use the Playwright browser tools to navigate and screenshot:

1. Resize the browser using `browser_resize` with the appropriate width and height
2. Navigate to the URL using `browser_navigate`
3. Wait for the page to be ready (use `browser_wait_for` if needed for dynamic content)
4. Take a full-page screenshot: use `browser_take_screenshot` with `filename` set to `/tmp/screenote-capture.png` and `type` set to `png`

### Step 4: Upload to Screenote

Call the `create_screenshot_upload` MCP tool to get a signed upload URL:

```
Tool: create_screenshot_upload
Arguments:
  project_id: <from step 1>
  page_name: <URL path of the page> — e.g., "/login", "/settings/profile". Append " (mobile)" if mobile viewport was used. Always use the URL path so that captures from `/screenote` and `/snapshot` group under the same page.
  title: <version label> — use the current date (e.g., "2025-06-15") or a short descriptor (e.g., "v1", "after redesign")
  mime_type: "image/png"
```

**page_name vs title:** `page_name` groups uploads into a page; `title` labels each version within it. Omit `page_name` to fall back to flat (title-only) behavior.

Then upload the file directly via curl (the image bytes never enter the LLM context):

```bash
curl -X PUT -H 'Content-Type: image/png' --data-binary @/tmp/screenote-capture.png '<upload_url>'
```

The MCP tool response includes `screenshot_id`, `upload_url`, and `annotate_url`.

### Step 5: Report to User

Tell the user:
- The screenshot was uploaded successfully
- Say "Uploaded to **<project_name>**" and provide the **annotate URL** so they can open it in the browser and add annotations
- Tell them to run `/feedback` when they're done annotating

Clean up the temp file:
```bash
rm -f /tmp/screenote-capture.png
```

