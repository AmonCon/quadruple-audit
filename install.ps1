# One-line installer for the quadruple-audit skill (Windows).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1     # auto-detect
#   powershell -ExecutionPolicy Bypass -File install.ps1 <target_dir>
#   $env:QUADRUPLE_AUDIT_SKILLS_DIR = '<dir>'; .\install.ps1
#
# The skill is plain Markdown + prompts: copying SKILL.md (and friends) into the
# skills directory of your agent is the whole installation.

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).Path }

$target = $args[0]
if (-not $target -and $env:QUADRUPLE_AUDIT_SKILLS_DIR) { $target = $env:QUADRUPLE_AUDIT_SKILLS_DIR }
if (-not $target) {
  $candidates = @(
    (Join-Path $HOME '.claude\skills'),
    (Join-Path $HOME '.agents\skills')
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { $target = $c; break }
  }
}
if (-not $target) {
  $target = Join-Path $HOME '.agents\skills'
  Write-Host "No agent skills directory found; creating $target (works for ZCode and most agents)."
}

$dest = Join-Path $target 'quadruple-audit'
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'examples') | Out-Null
Copy-Item (Join-Path $here 'SKILL.md'), (Join-Path $here 'README.md'), (Join-Path $here 'LICENSE') -Destination $dest -Force
Copy-Item (Join-Path $here 'examples\sample-report.md') -Destination (Join-Path $dest 'examples') -Force

Write-Host "Installed quadruple-audit into $dest"
Write-Host 'Invoke it with: /quadruple-audit <要检查的问题>'
