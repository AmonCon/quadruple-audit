#!/usr/bin/env bash
# One-line installer for the quadruple-audit skill (macOS / Linux / Git Bash).
#
# Usage:
#   ./install.sh                    # detect the agent skills directory automatically
#   ./install.sh <target_dir>       # install into a specific directory
#   QUADRUPLE_AUDIT_SKILLS_DIR=<dir> ./install.sh
#
# The skill is plain Markdown + prompts: copying SKILL.md (and friends) into the
# skills directory of your agent is the whole installation.

set -euo pipefail
cd "$(dirname "$0")"

# Candidate skills directories, in order of preference. Detection stops at the
# first one that already exists on this machine.
CANDIDATES=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.config/opcode/skills"
)

TARGET="${1:-${QUADRUPLE_AUDIT_SKILLS_DIR:-}}"
if [ -z "$TARGET" ]; then
  for dir in "${CANDIDATES[@]}"; do
    if [ -d "$dir" ]; then
      TARGET="$dir"
      break
    fi
  done
fi
if [ -z "$TARGET" ]; then
  TARGET="$HOME/.agents/skills"
  echo "No agent skills directory found; creating $TARGET (works for ZCode and most agents)."
fi

mkdir -p "$TARGET/quadruple-audit/examples"
cp SKILL.md README.md LICENSE "$TARGET/quadruple-audit/"
cp examples/sample-report.md "$TARGET/quadruple-audit/examples/"

echo "Installed quadruple-audit into $TARGET/quadruple-audit"
echo "Invoke it with: /quadruple-audit <要检查的问题>"
