# claude-screenote

Give your AI coding agent eyes. Screenshot any page, annotate it in Screenote, and let Claude Code read your feedback — all without leaving the terminal.

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
