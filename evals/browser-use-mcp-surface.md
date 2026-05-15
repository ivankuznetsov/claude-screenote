# Browser Use MCP Tool Surface

Last checked: 2026-05-15.

Sources:
- Official Browser Use MCP docs: https://docs.browser-use.com/open-source/customize/integrations/mcp-server
- Official Browser Use CLI docs: https://docs.browser-use.com/open-source/browser-use-cli
- Local smoke command: `bash evals/browser-use-mcp-smoke.sh`

## Local MCP Launch

The plugin launches Browser Use with:

```bash
uvx --from browser-use[cli] browser-use --mcp
```

The official MCP docs document that exact `uvx --from 'browser-use[cli]' browser-use --mcp` launch form and the `BROWSER_USE_HEADLESS` environment variable. The plugin sets `BROWSER_USE_HEADLESS=false` so the manual-login flow opens a visible Chromium window by default.

## Pinned Direct-Control Tools

The local smoke test verifies these current tool names:

- `browser_navigate`
- `browser_click`
- `browser_type`
- `browser_get_state`
- `browser_extract_content`
- `browser_get_html`
- `browser_screenshot`
- `browser_scroll`
- `browser_go_back`
- `browser_list_tabs`
- `browser_switch_tab`
- `browser_close_tab`
- `retry_with_browser_use_agent`
- `browser_list_sessions`
- `browser_close_session`
- `browser_close_all`

`browser_screenshot` currently exposes a `full_page` boolean. The skill docs must not assume other screenshot parameter names.

## Viewport Sizing

The current local Browser Use MCP tool surface does not expose a viewport-sizing or resize tool. The Screenote skills must therefore stop before requesting upload URLs when desktop/tablet/mobile dimensions cannot be set. Uploading current-browser-size screenshots as desktop/tablet/mobile would corrupt the Screenote review surface.
