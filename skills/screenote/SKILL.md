---
name: screenote
description: Capture a page screenshot, upload to Screenote for human annotation, and retrieve feedback
user_invocable: true
argument: "[url-or-description] or 'feedback'"
---

# Screenote — Visual Feedback Loop

You are executing the Screenote skill. This connects Claude Code to Screenote for visual feedback: screenshot a page, upload it for human annotation, then retrieve the feedback.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `feedback` → go to **Feedback Mode**
- Otherwise → go to **Capture Mode**

---

## Capture Mode

The user provided a URL or page description. Your job: screenshot it, upload to Screenote, return the annotation URL.

### Step 1: Pick a Project

Determine the **local project name** from the current working directory (e.g., the repo/folder name).

Call the `list_projects` MCP tool to get the user's Screenote projects. Each project has an `id` and a `name`. Always refer to projects by **name** — use `id` only internally for API calls.

**Matching logic:**
- If a Screenote project name matches the local project name (case-insensitive), use it automatically
- If no match is found (even if there's only one project), ask the user: list existing project names and offer to create a new one matching the local project name via the `create_project` MCP tool

### Step 2: Resolve the URL

- If the argument looks like a full URL (starts with `http`), use it directly
- If it looks like a relative path (e.g., `/login`, `dashboard`), prepend `http://localhost:3000/`
- If it's a description (e.g., "login page"), figure out the URL from context (check routes, running servers, etc.)

### Step 3: Take Screenshot

Use the Playwright browser tools to navigate and screenshot:

1. Navigate to the URL using `browser_navigate`
2. Wait for the page to be ready (use `browser_wait_for` if needed for dynamic content)
3. Take a full-page screenshot: use `browser_take_screenshot` with `filename` set to `/tmp/screenote-capture.png` and `type` set to `png`

### Step 4: Upload to Screenote

Call the `create_screenshot_upload` MCP tool to get a signed upload URL:

```
Tool: create_screenshot_upload
Arguments:
  project_id: <from step 1>
  title: <descriptive title based on the URL or user input>
  mime_type: "image/png"
```

Then upload the file directly via curl (the image bytes never enter the LLM context):

```bash
curl -X PUT -H 'Content-Type: image/png' --data-binary @/tmp/screenote-capture.png '<upload_url>'
```

The MCP tool response includes `screenshot_id`, `upload_url`, and `annotate_url`.

### Step 5: Report to User

Tell the user:
- The screenshot was uploaded successfully
- Provide the **annotate URL** so they can open it in the browser and add annotations
- Tell them to run `/screenote feedback` when they're done annotating

Clean up the temp file:
```bash
rm -f /tmp/screenote-capture.png
```

---

## Feedback Mode

The user ran `/screenote feedback`. Your job: fetch annotations and present the feedback.

### Step 1: Pick a Project

Follow the same matching logic as Capture Mode Step 1: match local project name to Screenote project names, ask user if no match.

### Step 2: Pick a Screenshot

Call `list_screenshots` for the matched project. Show the user a list of recent screenshots by **title** and let them pick one. If there's only one screenshot, use it automatically.

### Step 3: Fetch Annotations

Call the `list_annotations` MCP tool:

```
Tool: list_annotations
Arguments:
  project_id: <project_id>
  screenshot_id: <screenshot_id>
  status: "open"
```

### Step 4: Get Visual Context

For each annotation, call `get_annotation` to retrieve the cropped image of the annotated region:

```
Tool: get_annotation
Arguments:
  project_id: <project_id>
  annotation_id: <annotation_id>
```

This returns the annotation details plus a base64-encoded cropped image of the exact region the user marked.

### Step 5: Present Feedback

For each annotation, present it clearly with the visual context:

```
## Annotation #1 (point at 50%, 30%)
**Author:** designer@example.com
**Comment:** This button color is wrong
[cropped image shown]
```

For region annotations, include the dimensions:
```
## Annotation #2 (region at 10%, 20% — 30% x 15%)
**Author:** designer@example.com
**Comment:** This entire section needs more padding
[cropped image shown]
```

### Step 6: Offer Next Steps

After presenting all annotations, ask the user if they'd like you to:
- Address a specific annotation (and mark it resolved via `resolve_annotation` when done)
- Address all annotations one by one
- Take a new screenshot after making fixes (`/screenote <url>`)
