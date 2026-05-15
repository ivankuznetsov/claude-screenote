# Evaluations

## Structural Linting

Deterministic checks on SKILL.md files — no API calls, runs instantly.

    ./evals/lint-skills.sh

Validates:
- All skill directories exist with SKILL.md files
- Frontmatter fields (name, description, user_invocable, argument)
- Cross-references between skills point to existing files
- Viewport values (1280x800 desktop, 768x1024 tablet, 390x844 mobile) are consistent
- MCP tool names are present where expected

Run on every PR that touches `skills/**/*.md`.

## Browser Use MCP Smoke

Live smoke test for the bundled Browser Use MCP server:

    bash evals/browser-use-mcp-smoke.sh

Validates:
- `uvx --from browser-use[cli] browser-use --mcp` starts
- The expected Browser Use MCP direct-control tool names are present
- `browser_screenshot` exposes `full_page`
- The current server still has no viewport-sizing tool, so the skills must fail loudly before upload when fixed desktop/tablet/mobile dimensions are required

Run manually before changing browser-use capture behavior. It starts a local MCP subprocess and may install Python packages through `uv`.

## Trigger Eval Dataset

`trigger-eval-set.json` contains 14 test queries mapping to expected skill triggers. This dataset is ready for use when Claude Code provides proper skill trigger testing support (e.g., a `--dry-run` flag, skill match metadata in output, or `cc-plugin-eval` maturity).

### Why trigger evals are deferred

Tested `claude -p --output-format json` on 2025-03-10. Findings:
- Output is a flat result object — no message-level tool_use events exposed
- `--allowedTools "Skill"` does not restrict tool usage as expected
- Single query cost ~$0.38 (Opus), not viable for a 14-query eval suite
- Skills don't trigger as discrete `Skill` tool calls in headless mode

## CI Notes

- Lint evals: run on every PR (free, instant)
- Trigger evals: revisit when tooling improves
