# Installer for the quadruple-audit skill (Windows).
#
# Local (from a clone):  powershell -ExecutionPolicy Bypass -File install.ps1 [target_dir]
# Remote (one-liner):    irm https://github.com/AmonCon/quadruple-audit/raw/main/install.ps1 | iex
#                        (target override: $env:QUADRUPLE_AUDIT_SKILLS_DIR = '<dir>' first)
#
# The skill is plain Markdown + prompts: copying SKILL.md (and friends) into
# the skills directory of your agent is the whole installation.

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).Path }
$tmp = $null

# Remote mode: piped in, or not run from the repo (a clone has SKILL.md and
# its sibling installer; a bare or stale skills copy has neither) -> download
# the latest from GitHub into a temp dir.
if (-not $PSScriptRoot -or -not (Test-Path (Join-Path $here 'SKILL.md')) -or -not (Test-Path (Join-Path $here 'install.sh'))) {
  Write-Host 'No local copy found; fetching latest from GitHub...'
  $tmp = Join-Path $env:TEMP ('qa-install-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $tgz = Join-Path $tmp 'quadruple-audit.tar.gz'
  Invoke-WebRequest -Uri 'https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz' -OutFile $tgz -UseBasicParsing
  tar -xzf $tgz -C $tmp
  $here = Join-Path $tmp 'quadruple-audit-main'
}

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

$version = (Select-String -Path (Join-Path $dest 'SKILL.md') -Pattern '^version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
Write-Host "Installed quadruple-audit v$version into $dest"
Write-Host 'Invoke it with: /quadruple-audit <要检查的问题>'

if ($tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
