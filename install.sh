#!/usr/bin/env bash
# Installer for the quadruple-audit skill.
#
# Local (from a clone):  ./install.sh [target_dir]
# Remote:                run this script from anywhere else — it downloads the
#                        latest files from GitHub first (exact one-liner: see README).
# Target override:       QUADRUPLE_AUDIT_SKILLS_DIR=<dir> ./install.sh
#
# The skill is plain Markdown + prompts: copying SKILL.md (and friends) into
# the skills directory of your agent is the whole installation.

set -euo pipefail
cd "$(dirname "$0")" 2>/dev/null || cd .

# Repo detection: a clone has SKILL.md AND its sibling installer; a bare or
# stale skills copy has neither -> download the latest from GitHub instead.
# (Downloading to a file first, never piping into a shell.)
if [ ! -f SKILL.md ] || [ ! -f install.ps1 ]; then
  echo "Fetching latest from GitHub..."
  TMPD="$(mktemp -d)"
  trap 'rm -rf "$TMPD"' EXIT
  curl -fsSL -o "$TMPD/qa.tar.gz" "https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz"
  tar -xzf "$TMPD/qa.tar.gz" -C "$TMPD"
  cd "$TMPD/quadruple-audit-main"
fi

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

VERSION="$(grep -m1 '^version:' SKILL.md | sed 's/^version:[[:space:]]*//')"
echo "Installed quadruple-audit v${VERSION:-unknown} into $TARGET/quadruple-audit"
echo "Invoke it with: /quadruple-audit <要检查的问题>"
