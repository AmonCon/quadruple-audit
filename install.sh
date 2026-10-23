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

# Download the repo tarball, falling back to public GitHub mirrors. In mainland
# China raw.githubusercontent.com and sometimes github.com itself are
# unreachable; the mirrors were reachable when this was written. Override the
# whole list with QUADRUPLE_AUDIT_MIRROR=<url-prefix> if you have your own.
fetch_repo() {
  local dest="$1"
  local urls=(
    "https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz"
    "https://ghproxy.net/https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz"
    "https://gh-proxy.com/https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz"
    "https://ghfast.top/https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz"
  )
  if [ -n "${QUADRUPLE_AUDIT_MIRROR:-}" ]; then
    urls=("${QUADRUPLE_AUDIT_MIRROR%/}/https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz")
  fi
  local url
  for url in "${urls[@]}"; do
    echo "Trying $url"
    if curl -fsSL --connect-timeout 15 --max-time 120 -o "$dest" "$url" && tar -tzf "$dest" >/dev/null 2>&1; then
      return 0
    fi
    echo "  ...failed"
  done
  echo "Every download source failed. Check your network, or clone the repo and run ./install.sh locally." >&2
  return 1
}

# Repo detection: a clone has SKILL.md AND its sibling installer; a bare or
# stale skills copy has neither -> download the latest from GitHub instead.
# (Downloading to a file first, never piping into a shell.)
if [ ! -f SKILL.md ] || [ ! -f install.ps1 ]; then
  echo "Fetching latest from GitHub..."
  TMPD="$(mktemp -d)"
  trap 'rm -rf "$TMPD"' EXIT
  fetch_repo "$TMPD/qa.tar.gz"
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

# Only the first detected directory gets the skill. Say which ones were skipped
# instead of silently leaving other agents on an old copy.
if [ -z "${1:-}${QUADRUPLE_AUDIT_SKILLS_DIR:-}" ]; then
  SKIP_COUNT=0
  for dir in "${CANDIDATES[@]}"; do
    if [ -d "$dir" ] && [ "$dir" != "$TARGET" ]; then
      if [ "$SKIP_COUNT" -eq 0 ]; then
        echo "Also found other agent skill directories (not installed):"
      fi
      echo "  $dir"
      SKIP_COUNT=$((SKIP_COUNT + 1))
    fi
  done
  if [ "$SKIP_COUNT" -gt 0 ]; then
    echo "Run again with QUADRUPLE_AUDIT_SKILLS_DIR=<dir> to install there too."
  fi
fi

mkdir -p "$TARGET/quadruple-audit/examples"
cp SKILL.md README.md LICENSE "$TARGET/quadruple-audit/"
cp examples/sample-report.md "$TARGET/quadruple-audit/examples/"

VERSION="$(grep -m1 '^version:' SKILL.md | sed 's/^version:[[:space:]]*//')"
echo "Installed quadruple-audit v${VERSION:-unknown} into $TARGET/quadruple-audit"
echo "Invoke it with: /quadruple-audit <要检查的问题>"
