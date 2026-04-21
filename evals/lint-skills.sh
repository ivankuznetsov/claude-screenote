#!/bin/bash
# Lint SKILL.md files for structural correctness
# Requires: bash, grep
# Usage: ./evals/lint-skills.sh

set -euo pipefail
PASS=0
FAIL=0

fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }

SKILLS_DIR="skills"

# Check all skill directories exist and contain SKILL.md
for skill in screenote snapshot feedback; do
  if [ -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
    pass "$skill/SKILL.md exists"
  else
    fail "$skill/SKILL.md missing"
  fi
done

# Validate frontmatter fields in each SKILL.md
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  for field in name description user_invocable argument; do
    if grep -q "^${field}:" "$skill_file"; then
      pass "$skill_name has frontmatter field '$field'"
    else
      fail "$skill_name missing frontmatter field '$field'"
    fi
  done
done

# Validate cross-references point to existing files
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  refs=$(grep -oP '\(`skills/[^`]+`\)' "$skill_file" | grep -oP 'skills/[^`]+' || true)
  for ref in $refs; do
    if [ -f "$ref" ]; then
      pass "$skill_name cross-reference to $ref is valid"
    else
      fail "$skill_name cross-reference to $ref is broken"
    fi
  done
done

# Validate viewport values are consistent across skills
DESKTOP_W="1440"
DESKTOP_H="900"
MOBILE_W="393"
MOBILE_H="852"

for skill_file in "$SKILLS_DIR"/screenote/SKILL.md "$SKILLS_DIR"/snapshot/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  for val in "$DESKTOP_W" "$DESKTOP_H" "$MOBILE_W" "$MOBILE_H"; do
    if grep -q "$val" "$skill_file"; then
      pass "$skill_name contains viewport value $val"
    else
      fail "$skill_name missing viewport value $val"
    fi
  done
done

# Validate MCP tool names are consistent across skills
MCP_TOOLS="list_projects create_project create_screenshot_upload"
for tool in $MCP_TOOLS; do
  for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
    skill_name=$(basename "$(dirname "$skill_file")")
    if grep -q "$tool" "$skill_file"; then
      pass "$skill_name references MCP tool '$tool'"
    fi
  done
done

# Check feedback-specific MCP tools
FEEDBACK_TOOLS="list_pages list_screenshots list_annotations get_annotation resolve_annotation"
for tool in $FEEDBACK_TOOLS; do
  if grep -q "$tool" "$SKILLS_DIR/feedback/SKILL.md"; then
    pass "feedback references MCP tool '$tool'"
  else
    fail "feedback missing expected MCP tool '$tool'"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
