---
name: screenote
description: Capture a page screenshot, upload to Screenote for human annotation, and retrieve feedback
user_invocable: true
argument: "[url-or-description] or 'feedback [screenshot-id]'"
---

# Screenote — Visual Feedback Loop

You are executing the Screenote skill. This connects Claude Code to Screenote for visual feedback: screenshot a page, upload it for human annotation, then retrieve the feedback.

## Required Environment

- `SCREENOTE_API_KEY` — your Screenote API key (starts with `sk_proj_...`)
- `SCREENOTE_URL` — Screenote instance URL (defaults to `https://screenote.ai`)

## Step 0: Validate Environment

Before doing anything, check that the API key is set:

```bash
test -n "$SCREENOTE_API_KEY" || echo "ERROR: SCREENOTE_API_KEY is not set"
```

If not set, tell the user to set it and stop. Set the base URL:

```bash
SCREENOTE_BASE="${SCREENOTE_URL:-https://screenote.ai}"
```

## Mode Detection

Parse the user's argument:

- If the argument starts with `feedback` → go to **Feedback Mode**
- Otherwise → go to **Capture Mode**

---

## Capture Mode

The user provided a URL or page description. Your job: screenshot it, upload to Screenote, return the annotation URL.

### Step 1: Resolve the URL

- If the argument looks like a full URL (starts with `http`), use it directly
- If it looks like a relative path (e.g., `/login`, `dashboard`), prepend `http://localhost:3000/`
- If it's a description (e.g., "login page"), figure out the URL from context (check routes, running servers, etc.)

### Step 2: Take Screenshot

Use the Playwright browser tools to navigate and screenshot:

1. Navigate to the URL using `browser_navigate`
2. Wait for the page to be ready (use `browser_wait_for` if needed for dynamic content)
3. Take a viewport screenshot: use `browser_take_screenshot` with `filename` set to `/tmp/screenote-capture.png` and `type` set to `png`

### Step 3: Upload to Screenote

Upload the screenshot via the REST API using curl:

```bash
curl -s -X POST "${SCREENOTE_BASE}/api/v1/screenshots" \
  -H "Authorization: Bearer ${SCREENOTE_API_KEY}" \
  -F "title=<descriptive title based on the URL or user input>" \
  -F "image=@/tmp/screenote-capture.png"
```

The response is JSON:
```json
{
  "screenshot_id": 42,
  "annotate_url": "https://screenote.ai/projects/1/screenshots/42"
}
```

### Step 4: Report to User

Tell the user:
- The screenshot was uploaded successfully
- Provide the **annotate URL** so they can add annotations
- Tell them to run `/screenote feedback <screenshot_id>` when they're done annotating

Clean up the temp file:
```bash
rm -f /tmp/screenote-capture.png
```

---

## Feedback Mode

The user ran `/screenote feedback [screenshot-id]`. Your job: fetch annotations and present the feedback.

### Step 1: Parse the Screenshot ID

Extract the screenshot ID from the argument. If not provided, ask the user for it.

### Step 2: Fetch Annotations

Use curl to list open annotations for this screenshot:

```bash
curl -s "${SCREENOTE_BASE}/api/v1/screenshots/${SCREENSHOT_ID}/annotations?status=open" \
  -H "Authorization: Bearer ${SCREENOTE_API_KEY}"
```

The response is JSON:
```json
{
  "annotations": [
    {
      "id": 1,
      "type": "point",
      "coordinates": { "x_percent": 50.0, "y_percent": 30.0 },
      "comment": "This button color is wrong",
      "status": "open",
      "author": "designer@example.com"
    }
  ]
}
```

### Step 3: Present Feedback

For each annotation, present it clearly:

```
## Annotation #1 (point at 50%, 30%)
**Author:** designer@example.com
**Comment:** This button color is wrong
```

For region annotations, include the dimensions:
```
## Annotation #2 (region at 10%, 20% — 30% × 15%)
**Author:** designer@example.com
**Comment:** This entire section needs more padding
```

### Step 4: Offer Next Steps

After presenting all annotations, ask the user if they'd like you to:
- Address a specific annotation
- Address all annotations
- Take a new screenshot after making fixes (`/screenote <url>`)
