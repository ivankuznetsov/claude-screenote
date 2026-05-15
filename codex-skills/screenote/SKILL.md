---
name: screenote
description: Capture a page at desktop/tablet/mobile viewports and upload to Screenote for human annotation
metadata:
  argument: "[desktop|tablet|mobile] [url-or-description]"
---

# Screenote — Visual Feedback Loop

You are executing the Screenote skill. This connects Codex to Screenote for visual feedback: screenshot a page at three viewports by default (desktop, tablet, mobile) and upload them as one logical Screenshot that the human can annotate per-viewport.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `feedback` → tell the user: "Feedback has moved to its own command. Run `$screenote:feedback` instead." Stop.
- If the argument starts with `desktop`, `tablet`, or `mobile` → **single-viewport mode**: capture only that viewport (strip the keyword from the argument; the rest is the URL/description).
- Otherwise → **multi-viewport mode (default)**: capture all three viewports (desktop + tablet + mobile) as one Screenshot.

## Viewport Dimensions

Fixed defaults (match Screenote server's canonical set):

| Viewport | Dimensions | Notes |
|---|---|---|
| `desktop` | **1280 × 800** | Standard laptop / small desktop |
| `tablet`  | **768 × 1024** | iPad mini |
| `mobile`  | **390 × 844** | iPhone 14 |

---

## Full-Page Capture

By default, `$screenote:screenote` captures the entire scrolling page, not only the first viewport. Pages taller than **5000 px** are capped at the first 5000 px (or after **10** downward scrolls, whichever fires first), and lazy-loaded pages are scrolled before capture. Sticky headers, footers, and sidebars stay in place; if stitching is needed, repeated sticky elements are expected.

Use the direct-control tools exposed by the `browser-use` MCP server. The pinned smoke test in `evals/browser-use-mcp-smoke.sh` verifies `browser_navigate`, `browser_get_state`, `browser_get_html`, `browser_screenshot`, `browser_scroll`, and `browser_screenshot.full_page`. It also verifies that the current local MCP surface has no viewport-sizing tool. If the active `browser-use` MCP server does not expose a way to set the target viewport dimensions, fail loudly before requesting upload URLs: stop processing, do not upload partial or wrong-dimension screenshots, and tell the user exactly that Browser Use MCP lacks viewport sizing for Screenote's desktop/tablet/mobile capture contract. This canonical rule is referenced from §4c step 1 and from `$screenote:snapshot` Strategy B.

Full-page procedure for each viewport:

Before the loop, set `SCREENOTE_OUTPUT` to the target PNG path for this viewport. For `$screenote:screenote`, use `$SCREENOTE_DIR/<viewport>.png`; `$screenote:snapshot` may set a route-scoped path such as `$SCREENOTE_DIR/<i>-<viewport>.png`. Also ensure `SCREENOTE_STATUS="$SCREENOTE_DIR/run-status.jsonl"` exists. Record per-viewport facts in that JSONL file, not only in working memory: `cap_fired`, `unsettled_poll`, `unverified_scroll_top`, `failed`, and `failure_reason`.

1. After navigating, settle the page by polling `browser_get_state` and/or `browser_get_html` until loading UI is gone and URL/title/HTML size/interactive-element count are stable across consecutive checks. Do not use fixed sleeps. Cap this poll at **15 iterations**; if the page never stabilizes (live clock, animated counter, auto-refreshing feed), proceed anyway and record `unsettled_poll=true` in `run-status.jsonl` so the caller's summary can say the screenshot was taken under a still-changing page.
2. Read the page-state metadata to get the current viewport height, current scroll position, and document height. If height metadata is unavailable, continue with the scroll loop but report that the cap was enforced by scroll count.
3. Scroll downward by one viewport at a time with `browser_scroll`. After each scroll, poll page state again so lazy-loaded content can extend the page. Stop when the document height no longer grows between consecutive scrolls, the total scrolled distance reaches **5000 px**, or **10** downward scrolls have run, whichever happens first. If the 5000 px or 10-scroll limit stopped the loop, set `cap_fired = true`.
4. Scroll back to the top. Use upward scrolls and verify via page-state metadata that the scroll position returned to zero before capturing. If the page-state metadata does not expose scroll position, record `unverified_scroll_top=true` and do **not** use the preferred full-page crop path; use the fallback tile path only if visible screenshots can be captured after the upward-scroll attempts. If top position still cannot be made credible, fail loudly instead of uploading a possibly mid-page crop.
5. Preferred capture path: call `browser_screenshot` with `full_page: true` only when the active tool schema exposes that exact field. The tool returns the PNG as MCP image content (base64-encoded `data` field on an `image` content block). Write the `data` value to `$SCREENOTE_OUTPUT.b64`, then decode it with `base64 -d "$SCREENOTE_OUTPUT.b64" > "$SCREENOTE_OUTPUT"`. If the image content is too large for the MCP client and the tool call fails before returning bytes, switch to the fallback tile path. Preflight ImageMagick before checking dimensions:
   ```bash
   if command -v magick >/dev/null 2>&1; then
     IM_IDENTIFY='magick identify'
     IM_CONVERT='magick convert'
   elif command -v identify >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
     IM_IDENTIFY='identify'
     IM_CONVERT='convert'
   else
     echo "ImageMagick is required for Screenote full-page captures (install magick or identify/convert)." >&2
     exit 1
   fi
   $IM_IDENTIFY -format "%wx%h" "$SCREENOTE_OUTPUT"
   $IM_CONVERT "$SCREENOTE_OUTPUT" -crop x5000+0+0 +repage "$SCREENOTE_OUTPUT.tmp.png"
   mv "$SCREENOTE_OUTPUT.tmp.png" "$SCREENOTE_OUTPUT"
   ```
   Only run the crop commands when the measured height is greater than 5000 px; when cropping, record `cap_fired=true` and warn that the 5000 px cap can bisect page content.
6. Fallback capture path: if the screenshot tool cannot capture full-page images but can capture the visible viewport, capture viewport-sized PNG tiles while scrolling from top to bottom. Decode and write each tile as `${SCREENOTE_OUTPUT%.png}-tile-001.png`, `${SCREENOTE_OUTPUT%.png}-tile-002.png`, etc. using a zero-padded three-digit index so lexicographic shell ordering matches scroll order even past nine tiles and different viewports/routes cannot reuse stale tiles. Stop at the 5000 px or 10-scroll cap (setting `cap_fired = true` if the cap fired). If no tile files were produced, fail loudly. Stitch with `$IM_CONVERT "${SCREENOTE_OUTPUT%.png}"-tile-*.png -append "$SCREENOTE_OUTPUT"`, verify the output file exists, then crop to 5000 px using the temp-file pattern above if needed.
7. Last resort: if neither full-page screenshot nor visible-viewport screenshot plus scrolling is available, fail loudly with the missing browser-use MCP capability so the user knows to upgrade browser-use.
8. Append one JSON object to `run-status.jsonl` for this viewport before returning to the caller. Include `viewport`, `output`, `cap_fired`, `unsettled_poll`, `unverified_scroll_top`, `failed`, and `failure_reason`.

ImageMagick is required on the machine running the agent for **both** capture paths: the preferred path calls `identify` on every page and `convert` on any page taller than 5000 px, and the fallback path uses `convert` to stitch tiles. On ImageMagick 7+ the canonical binary is `magick`; the preflight above supports both `magick identify` / `magick convert` and the older `identify` / `convert` aliases.

---

## Project Cache

Call `list_projects` to verify the MCP connection and get the current project list. If the call fails with an auth error, tell the user to authorize the Screenote MCP server and stop.

Then check for a cached project selection:

1. Try to read `.screenote/screenote-cache.json` (relative to cwd). If it is missing, try the legacy `.claude/screenote-cache.json` path for backward compatibility. If a cache file exists and contains valid JSON with `project_id` and `project_name`, AND that `project_id` appears in the `list_projects` response, use that project and skip the "Pick a Project" step. Do not announce the cached selection.
2. If the cache is missing, invalid, or the `project_id` is not in the `list_projects` response (stale cache), delete the stale cache file if it exists and proceed with the normal "Pick a Project" step below. After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.screenote/screenote-cache.json` (create the `.screenote/` directory if needed).

---

## Capture Mode

The user provided a URL or page description. Your job: screenshot it at the chosen viewport(s) using the Full-Page Capture procedure above, upload to Screenote, and return the annotation URL.

### Step 1: Pick a Project

**Check the Project Cache first** (see Project Cache section above). The `list_projects` call has already been made there. If the cache provides a valid project, skip to Step 2.

If no cache hit, determine the **local project name** from the current working directory (e.g., the repo/folder name). Use the project list already fetched in the Project Cache step. Always refer to projects by **name** — use `id` only internally for API calls.

**Matching logic:**
- If a Screenote project name matches the local project name (case-insensitive), use it automatically
- If no match is found (even if there's only one project), ask the user: list existing project names and offer to create a new one matching the local project name via the `create_project` MCP tool

After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.screenote/screenote-cache.json`.

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

Only `screenshot_id` and `annotate_url` are used downstream; `page_id` is returned for debugging. Drive the capture loop from `uploads[i].viewport` — that field is authoritative for mapping bytes to viewport.

Capture screenshots *after* requesting upload URLs so tokens don't expire mid-capture.

### Step 4: Capture and Upload Each Viewport

This section is the canonical capture-and-upload procedure. `$screenote:snapshot` references it per-route.

#### 4a. Validate the response before shelling out

Before any `curl`, reject a response that could smuggle shell metacharacters through the instructions below:

1. Parse the `SCREENOTE_URL` env var (or default `https://screenote.ai`) from the `screenote` entry in `.mcp.json` `mcpServers` (the file now also contains a `browser-use` entry whose own URLs and env vars must be ignored here) to get the **expected host** (e.g., `screenote.ai`, or `localhost:3005` in dev).
2. For each entry in `uploads`, assert:
   - `upload_url` starts with `https://` (or `http://` if the expected host is `localhost`) and parses as a URL whose host equals the expected host. Otherwise abort with an error.
   - `viewport` is exactly one of `desktop`, `tablet`, `mobile`. Otherwise abort.

Never interpolate server-returned strings directly into shell commands — always go through a shell variable (see 4c).

#### 4b. Set up a per-invocation temp dir

```bash
SCREENOTE_DIR=$(mktemp -d /tmp/screenote-XXXXXX)
SCREENOTE_STATUS="$SCREENOTE_DIR/run-status.jsonl"
: > "$SCREENOTE_STATUS"
```

Fixed `/tmp/...` paths would collide with concurrent `$screenote:screenote` runs and are a symlink-attack target on shared machines; `mktemp -d` avoids both.

#### 4c. Capture and upload each viewport, serially

browser-use MCP keeps browser state in a shared session, so do **not** parallelize. For each `entry` in `uploads`, in order:

1. **Set viewport** to the dimensions from the Viewport Dimensions table above, keyed on `entry.viewport`, using the browser-use MCP viewport-sizing capability. If this capability is absent, stop before capture/upload and use the fail-loudly wording from the Full-Page Capture intro.
2. **Navigate** to the URL using `browser_navigate`. Fresh navigate per viewport — safer for SPAs that read viewport at mount time than a resize-only flow.
3. **Screenshot** by setting `SCREENOTE_OUTPUT="$SCREENOTE_DIR/<viewport>.png"` and running the Full-Page Capture procedure above (settling, scroll-down, scroll-back, capture, crop), producing PNG bytes at that path. Settling is handled inside that procedure — do not re-poll here.
4. **Upload** via curl using a shell variable for the URL — do not interpolate the value inline:
   ```bash
   UPLOAD_URL='<validated upload_url from 4a>'
   curl -fsS -X PUT -H 'Content-Type: image/png' \
     --data-binary @"$SCREENOTE_OUTPUT" \
     "$UPLOAD_URL"
   ```
   `-f` turns 4xx into a non-zero exit so the retry path (4d) can trigger.
5. **Track progress**: print `[<viewport>] uploaded`.

#### 4d. Token-expiry retry

If any `curl` exits non-zero with a 4xx status (token expired or rejected), call `create_multi_viewport_screenshot` **once** again for this same `(project_id, page_name, title)` to get fresh upload URLs, re-validate them (4a), and retry the remaining viewports from the start of the failed one. On a second failure, append `failed=true` and the upload error to `run-status.jsonl`, then continue with the next viewport; include failures in the Step 5 summary.

Note: re-calling `create_multi_viewport_screenshot` with the same `page_name`/`title` will create a new Screenshot grouped under the same Page. Acceptable for single-page retry; for batch runs (`$screenote:snapshot`), callers should decide whether to retry per-route or skip.

#### 4e. Clean up

```bash
rm -rf "$SCREENOTE_DIR"
```

Do not delete `$SCREENOTE_DIR` until Step 5 has read `run-status.jsonl`. After the user-facing report is composed, run cleanup whether capture succeeded or failed.

### Step 5: Report to User

Tell the user:
- The viewports that were uploaded (e.g. "Uploaded desktop / tablet / mobile")
- Say "Uploaded to **<project_name>**" and provide the **annotate_url** so they can open it in the browser and add annotations
- Mention they can switch between viewports in Screenote using the device-icon toolbar
- Tell them to run `$screenote:feedback` when they're done annotating
- Read `run-status.jsonl`; if `cap_fired` is true for any viewport, say "Captured the first 5000 px or 10 scrolls; the page may extend further and the crop may cut through content" and name which viewports were truncated
- If `unsettled_poll` or `unverified_scroll_top` is true for any viewport, name those viewports so the reviewer knows the capture happened under a degraded condition
- If any viewport failed after retry, list it explicitly
- After reading the ledger and composing this report, clean up `$SCREENOTE_DIR`
