---
name: feedback
description: Retrieve visual feedback and annotations from Screenote for the current project
user_invocable: true
argument: "[desktop|tablet|mobile] [page-name or version]"
---

# Feedback — Retrieve Visual Annotations

You are executing the Feedback skill. This retrieves human annotations from Screenote so you can act on visual feedback.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Argument Parsing

Before Step 1, normalize the argument:

1. If the first whitespace-separated token is exactly `desktop`, `tablet`, or `mobile`, consume it as the **viewport filter** for Step 3 and pass the *remainder* (possibly empty) as the page/version hint for Step 2.
2. Otherwise, the viewport filter is unset and the full argument is the page/version hint.

Examples:
- `/feedback` → viewport: none, hint: none
- `/feedback login` → viewport: none, hint: `login`
- `/feedback desktop` → viewport: `desktop`, hint: none
- `/feedback desktop login` → viewport: `desktop`, hint: `login`

Never match a viewport keyword against page names — that collision is the reason for the split above.

## Step 1: Resolve Project

Follow the **Project Cache** and **Pick a Project** procedure from the `/screenote` skill (`skills/screenote/SKILL.md`). The logic is identical: call `list_projects` first (auth gate), then check `.claude/screenote-cache.json`, match by local project name, or prompt the user.

If `list_projects` returned zero projects → say:
  "No Screenote projects found. Capture a page first with `/screenote <url>`." Stop.

## Step 2: Pick a Page and Version

If the **page/version hint** (from Argument Parsing above) is non-empty, use it as a case-insensitive selection hint when matching page names and version titles below. Auto-select only when there is exactly one clear match; otherwise fall back to interactive picking.

Call `list_pages` with project_id.
- Zero pages → "No screenshots in this project yet. Use `/screenote <url>` to capture a page first." Stop.
- One page → use it automatically
- Multiple pages → if the argument uniquely matches one page name, use it; otherwise show pages by name (with version count), let user pick

Call `list_screenshots` with project_id and page_id.
- Zero versions → "No screenshot versions found for this page yet. Capture one with `/screenote <url>` first." Stop.
- One version → use it
- Multiple → if the argument uniquely matches one version title, use it; otherwise show by title, let user pick

## Step 3: Fetch Annotations

Call `list_annotations` with project_id, screenshot_id, status: "open".

If the **viewport filter** was set in Argument Parsing, pass `viewport: <keyword>` as well so only annotations drawn against that layout come back.

If zero annotations → say:
  "No open annotations for this screenshot. Open the annotate URL to add feedback, or check if annotations are marked as resolved." Include annotate_url if available. Stop.

## Step 4: Get Visual Context

For each annotation, call `get_annotation` to retrieve the cropped image of the annotated region. The crop is pulled from the ScreenshotImage that matches `annotation.viewport` — so a mobile annotation shows the mobile-layout crop, not the desktop one.

## Step 5: Present Feedback

Header: "Feedback for **<project_name>** — <page_name> — <version_title>"

If annotations span multiple viewports, group them under subheadings: "Desktop (2 open)", "Tablet (1 open)", "Mobile (3 open)". Within a single-viewport response, a subheading is not needed.

For each annotation, show:
- Viewport label — "Desktop", "Tablet", or "Mobile" (Title Case, matching the subheading form above; layouts differ so this needs to be explicit)
- Type (point/region) with coordinates
- Author
- Comment text
- Cropped image (from the matching viewport's ScreenshotImage)

## Step 6: Offer Next Steps

After presenting all annotations, ask the user if they'd like to:
- Address a specific annotation (and mark it resolved via `resolve_annotation` when done)
- Address all annotations one by one, optionally scoped to one viewport ("let's fix mobile first")
- Take a new screenshot after making fixes (`/screenote <url>`)
