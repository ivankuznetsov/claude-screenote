# claude-screenote

Give your AI coding agent eyes. Screenshot any page — or snapshot your entire app — annotate in Screenote, and let Claude Code read your feedback — all without leaving the terminal.

## Quick Start

### 1. Install the plugin

In Claude Code, run:

```
/plugin marketplace add ivankuznetsov/claude-screenote
/plugin install claude-screenote@screenote-marketplace
```

### 2. Connect to Screenote

On first use, Claude Code will open a browser window to authorize access to your Screenote account.

### 3. Use it

Tell Claude Code to screenshot a page:

```
/screenote http://localhost:3000/login
```

You'll get a link to annotate the screenshot in Screenote. Draw on it, leave comments, then pull the feedback back:

```
/screenote feedback
```

Claude sees every annotation with its position and comment, and can start fixing things right away.

### 4. Snapshot your entire app

Take a visual snapshot of every page in your app at once:

```
/snapshot http://localhost:3000
```

The agent discovers all routes in your codebase, handles authentication, and screenshots each page. Every screenshot is tagged with the current date and last git commit hash.

## How It Works

```
You                       Claude Code                  Screenote
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
 │                            │── /screenote feedback ────►│
 │                            │◄── annotations + regions ──│
 │                            │                            │
 │                            │  (fixes code based on      │
 │                            │   your visual feedback)     │
 │                            │                            │
 │                            │── /screenote /login ──────►│
 │                            │  (screenshot to verify)     │
```

## Usage

### Screenshot a page

```
/screenote https://myapp.com/dashboard
```

Works with any URL your machine can reach — localhost, staging, production.

### Snapshot the entire app

```
/snapshot http://localhost:3000
```

The snapshot workflow:
1. **Discovers routes** — scans your codebase for route definitions (React Router, Next.js, Vue Router, Express, Django, Rails, etc.)
2. **Handles auth** — logs in if needed so authenticated pages are captured
3. **Screenshots every page** — navigates to each route and takes a full-page screenshot
4. **Tags with metadata** — every screenshot title includes the date and last git commit hash (e.g., `App Snapshot — 2025-06-15 — a1b2c3d — /dashboard`)
5. **Uploads to Screenote** — all screenshots are uploaded for review and annotation

Use `mobile` for mobile viewport: `/snapshot mobile http://localhost:3000`

### Read annotations

After you've annotated the screenshot in Screenote:

```
/screenote feedback
```

Claude matches your local project name to a Screenote project, lists recent screenshots by title, and lets you pick one. Each annotation is presented with its position and comment, then Claude offers to fix the issues.

### Natural language

You can also just describe what you want:

```
/screenote the signup page
```

Claude will figure out the URL from your project's routes.

### Project matching

The plugin automatically matches your local working directory name to a Screenote project. If no match is found, it asks you to pick an existing project or create a new one.

## Requirements

- A [Screenote](https://screenote.ai) account
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [Playwright plugin](https://github.com/anthropics/claude-plugins-official) for browser screenshots

## License

MIT
