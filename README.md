# claude-screenote

Visual feedback loop for Claude Code. Screenshot a page, upload to [Screenote](https://screenote.ai) for human annotation, then read the feedback — all from your terminal.

## Setup

### 1. Install the plugin

```bash
claude plugin add ivankuznetsov/claude-screenote
```

### 2. Set your API key

Get an API key from your Screenote project settings, then add it to your environment:

```bash
export SCREENOTE_API_KEY="sk_proj_..."
```

For a self-hosted instance:

```bash
export SCREENOTE_URL="https://your-instance.example.com"
```

## Usage

### Capture a page

```
/screenote http://localhost:3000/login
```

This will:
1. Open the URL in a headless browser
2. Take a viewport screenshot
3. Upload it to Screenote
4. Return a link where you (or your team) can annotate it

### Read feedback

After annotating in Screenote, pull the feedback back into Claude Code:

```
/screenote feedback 42
```

This fetches all open annotations for screenshot #42 and presents them with coordinates and comments.

### Relative paths

If you're working on a local dev server:

```
/screenote /dashboard
/screenote /users/new
```

These are resolved against `http://localhost:3000` by default.

## How It Works

```
Claude Code                    Screenote                    Human
    │                              │                          │
    ├── /screenote /login ────────►│                          │
    │   (screenshot + upload)      │                          │
    │                              │◄── annotate in browser ──┤
    │                              │                          │
    ├── /screenote feedback 42 ───►│                          │
    │   (fetch annotations)        │                          │
    │                              │                          │
    ├── fix code ──────────────────┤                          │
    │                              │                          │
    └── /screenote /login ────────►│  (verify fix)            │
```

## License

MIT
