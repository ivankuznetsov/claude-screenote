# Screenote

Give your AI coding agent eyes. Screenshot any page, snapshot your whole app, annotate in Screenote, and let Claude Code or Codex read the feedback without leaving the terminal.

**Supports Claude Code + Codex (GPT-5.5).**

## Quick Start

### Prerequisites

Screenote launches browser automation through the local [browser-use](https://github.com/browser-use/browser-use) MCP server with `uvx --from browser-use[cli] browser-use --mcp`. Install [uv](https://github.com/astral-sh/uv) and Python 3.11+ so the plugin can start that server on demand.

Also install **ImageMagick** — the default capture path uses `identify` to measure every page and `convert` to crop any page taller than 5000 px, so it is required, not optional. On ImageMagick 7+ the canonical binary is `magick`; `convert`/`identify` ship as compatibility aliases on most distros, but on IM7-only systems (recent Arch, Fedora 40+) you may need to invoke them as `magick convert` / `magick identify`.

### 1. Install the plugin

Recommended marketplace install:

```bash
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install screenote@aikuznetsov-marketplace
```

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open Codex's plugin UI (`/plugins`) and install **Screenote** from **AI Kuznetsov**.

Direct Claude Code install remains available for existing users:

```bash
/plugin marketplace add ivankuznetsov/screenote-skills
/plugin install screenote@screenote-marketplace
```

### 2. Connect to Screenote

On first use, the agent will authorize access to your Screenote account through the Screenote MCP server.

### 3. Use it

Tell the agent to screenshot a page:

```bash
/screenote http://localhost:3000/login
```

You'll get a link to annotate the screenshot in Screenote. Draw on it, leave comments, then pull the feedback back:

```bash
/feedback
```

The agent sees every annotation with its position and comment, and can start fixing things right away.

### 4. Snapshot your entire app

Take a visual snapshot of every page in your app at once:

```bash
/snapshot http://localhost:3000
```

The agent discovers all routes in your codebase, handles authentication, and screenshots each page. Every screenshot is tagged with the current date and last git commit hash.

## What's New

- Screenote now ships its own browser-use MCP server configuration instead of depending on a host-provided Playwright MCP server.
- `/screenote` and `/snapshot` capture full scrolling pages by default, not just the first viewport.
- Long or infinite-scroll pages are capped at the first **5000 px or 10 scrolls** (whichever fires first) so captures finish predictably.
- Sticky headers, footers, and sidebars are left in place. They can repeat if the fallback stitched capture path is used.

## How It Works

```
You                       Agent                        Screenote
 │                            │                            │
 │  "fix the login page"      │                            │
 │ ──────────────────────────►│                            │
 │                            │── /screenote /login ──────►│
 │                            │                            │
 │            open link, draw annotations, leave comments  │
 │ ◄──────────────────────────────────────────────────────►│
 │                            │                            │
 │  "ok read my feedback"     │                            │
 │ ──────────────────────────►│                            │
 │                            │── /feedback ──────────────►│
 │                            │◄── annotations + regions ──│
 │                            │                            │
 │                            │  (fixes code based on      │
 │                            │   your visual feedback)     │
 │                            │                            │
 │                            │── /screenote /login ──────►│
 │                            │  (screenshot to verify)     │
```

## Usage

Claude Code examples below use slash commands. In Codex, use the same skill names through the plugin namespace, for example `$screenote:screenote`, `$screenote:feedback`, and `$screenote:snapshot`.

### Screenshot a page

```bash
/screenote https://myapp.com/dashboard
```

Captures **three viewports by default** — desktop (1280×800), tablet (768×1024), and mobile (390×844) — and uploads them as one Screenshot. Each viewport is a full-page capture: the agent scrolls first to trigger lazy-loaded content, captures the scrolling page, and caps the image at 5000 px or 10 scrolls (whichever fires first). In Screenote, device icons let the reviewer switch between variants and annotate each layout independently.

Works with any URL your machine can reach — localhost, staging, production.

For a single viewport instead, prefix the argument:

```bash
/screenote desktop https://myapp.com/dashboard
/screenote tablet  https://myapp.com/dashboard
/screenote mobile  https://myapp.com/dashboard
```

### Snapshot the entire app

```bash
/snapshot http://localhost:3000
```

The snapshot workflow:
1. **Discovers routes** — scans your codebase for route definitions (React Router, Next.js, Vue Router, Express, Django, Rails, etc.)
2. **Handles auth** — logs in if needed so authenticated pages are captured
3. **Screenshots every page at three viewports** — desktop, tablet, mobile (default), full-page with the 5000 px or 10-scroll cap (whichever fires first)
4. **Tags with metadata** — every screenshot title includes the date and last git commit hash (e.g., `App Snapshot — 2025-06-15 — a1b2c3d — /dashboard`)
5. **Uploads to Screenote** — all viewports are uploaded; reviewers flip between them per page

For a single viewport, prefix the argument:

```bash
/snapshot desktop http://localhost:3000
/snapshot tablet  http://localhost:3000
/snapshot mobile  http://localhost:3000
```

### Read annotations

After you've annotated the screenshot in Screenote:

```bash
/feedback
```

The agent matches your local project name to a Screenote project, lists recent screenshots by title, and lets you pick one. Each annotation is presented with its position and comment, then the agent offers to fix the issues.

Filter by viewport by prefixing the argument:

```bash
/feedback desktop
/feedback mobile login
```

### Natural language

You can also just describe what you want:

```bash
/screenote the signup page
```

The agent will figure out the URL from your project's routes.

### Project matching

The plugin automatically matches your local working directory name to a Screenote project. If no match is found, it asks you to pick an existing project or create a new one.

## Requirements

- A [Screenote](https://screenote.ai) account
- Claude Code or Codex
- Python 3.11+ and [uv](https://github.com/astral-sh/uv) for the bundled browser-use MCP server
- ImageMagick (`convert` and `identify`, or `magick convert` / `magick identify` on ImageMagick 7+) — required on the **default** capture path (height check on every page and crop on any page taller than 5000 px), not just for fallback stitching
- The Screenote MCP server configured by this plugin

## License

MIT
