# claude-screenote

Give your AI coding agent eyes. Screenshot any page, annotate it in Screenote, and let Claude Code read your feedback — all without leaving the terminal.

## Quick Start

### 1. Install the plugin

```bash
claude plugin add ivankuznetsov/claude-screenote
```

### 2. Add your API key

Go to your project in [Screenote](https://screenote.ai), open **API Keys**, and create a new key. Then add it to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
export SCREENOTE_API_KEY="sk_proj_..."
```

Restart your terminal or run `source ~/.zshrc` for the change to take effect.

### 3. Use it

Tell Claude Code to screenshot a page:

```
/screenote http://localhost:3000/login
```

You'll get a link to annotate the screenshot in Screenote. Draw on it, leave comments, then pull the feedback back:

```
/screenote feedback 42
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
 │                            │── /screenote feedback 42 ─►│
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
/screenote feedback 42
```

Claude presents each annotation with its position and comment, then offers to fix the issues.

### Natural language

You can also just describe what you want:

```
/screenote the signup page
```

Claude will figure out the URL from your project's routes.

## Troubleshooting

### EXDEV error during install

If you see `EXDEV: cross-device link not permitted` when installing, this is a [known Claude Code bug](https://github.com/anthropics/claude-code/issues/18115) on Linux systems where `/home` and `/tmp` are on different filesystems (common with `tmpfs`).

Workaround — install manually:

```bash
# 1. Add the marketplace
/plugin marketplace add ivankuznetsov/claude-screenote

# 2. Copy plugin to the cache
PLUGIN_DIR="$HOME/.claude/plugins/cache/claude-screenote/claude-screenote/1.0.0"
mkdir -p "$PLUGIN_DIR"
cp -r "$HOME/.claude/plugins/marketplaces/claude-screenote/"{.claude-plugin,skills,LICENSE,README.md} "$PLUGIN_DIR/"

# 3. Register it (add this entry to ~/.claude/plugins/installed_plugins.json under "plugins")
```

Add this to the `"plugins"` object in `~/.claude/plugins/installed_plugins.json`:

```json
"claude-screenote@claude-screenote": [
  {
    "scope": "user",
    "installPath": "<your-home>/.claude/plugins/cache/claude-screenote/claude-screenote/1.0.0",
    "version": "1.0.0",
    "installedAt": "2025-01-01T00:00:00.000Z",
    "lastUpdated": "2025-01-01T00:00:00.000Z"
  }
]
```

Replace `<your-home>` with your actual home directory path. Restart Claude Code after.

## Requirements

- A [Screenote](https://screenote.ai) account with at least one project
- An API key from your project settings
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## License

MIT
