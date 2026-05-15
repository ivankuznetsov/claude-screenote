#!/bin/bash
# Smoke-test the local browser-use MCP tool surface used by the Screenote skills.
# Requires: uv, Python 3.11+
# Usage: bash evals/browser-use-mcp-smoke.sh

set -euo pipefail

uv run --with mcp --with "browser-use[cli]" python - <<'PY'
import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

EXPECTED_TOOLS = {
    "browser_navigate",
    "browser_click",
    "browser_type",
    "browser_get_state",
    "browser_extract_content",
    "browser_get_html",
    "browser_screenshot",
    "browser_scroll",
    "browser_go_back",
    "browser_list_tabs",
    "browser_switch_tab",
    "browser_close_tab",
    "retry_with_browser_use_agent",
    "browser_list_sessions",
    "browser_close_session",
    "browser_close_all",
}


async def main():
    params = StdioServerParameters(
        command="uvx",
        args=["--from", "browser-use[cli]", "browser-use", "--mcp"],
        env={"BROWSER_USE_HEADLESS": "true"},
    )

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()

    by_name = {tool.name: tool for tool in tools.tools}
    names = set(by_name)
    missing = sorted(EXPECTED_TOOLS - names)
    if missing:
        raise SystemExit(f"Missing expected browser-use MCP tools: {', '.join(missing)}")

    screenshot_schema = by_name["browser_screenshot"].inputSchema or {}
    screenshot_props = screenshot_schema.get("properties", {})
    if "full_page" not in screenshot_props:
        raise SystemExit("browser_screenshot schema no longer exposes full_page")

    viewport_like = sorted(
        name for name in names if "viewport" in name.lower() or "resize" in name.lower()
    )

    print("browser-use MCP tools:")
    for name in sorted(names):
        print(f"- {name}")

    print("")
    print("browser_screenshot schema:")
    print(json.dumps(screenshot_schema, indent=2, sort_keys=True))

    print("")
    if viewport_like:
        print("Viewport-like tools detected:")
        for name in viewport_like:
            print(f"- {name}")
    else:
        print("No viewport-sizing tool detected; Screenote skills must fail loudly before upload.")


try:
    asyncio.run(main())
except Exception as exc:
    print(f"browser-use MCP smoke failed: {exc}", file=sys.stderr)
    raise
PY
