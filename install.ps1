# Installer for the quadruple-audit skill (Windows).
#
# Local (from a clone):  powershell -ExecutionPolicy Bypass -File install.ps1 [target_dir]
# Remote (download first):  irm https://github.com/AmonCon/quadruple-audit/raw/main/install.ps1 -OutFile install-qa.ps1
#                           powershell -ExecutionPolicy Bypass -File install-qa.ps1
#                           (target override: $env:QUADRUPLE_AUDIT_SKILLS_DIR = '<dir>' first)
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
  # Mirrors: raw.githubusercontent.com and sometimes github.com are unreachable
  # in mainland China. Set QUADRUPLE_AUDIT_MIRROR to use your own prefix.
  $repoPath = 'https://github.com/AmonCon/quadruple-audit/archive/refs/heads/main.tar.gz'
  if ($env:QUADRUPLE_AUDIT_MIRROR) {
    $urls = @($env:QUADRUPLE_AUDIT_MIRROR.TrimEnd('/') + '/' + $repoPath)
  } else {
    $urls = @(
      $repoPath,
      'https://ghproxy.net/' + $repoPath,
      'https://gh-proxy.com/' + $repoPath,
      'https://ghfast.top/' + $repoPath
    )
  }
  $ok = $false
  foreach ($url in $urls) {
    Write-Host "Trying $url"
    try {
      Invoke-WebRequest -Uri $url -OutFile $tgz -UseBasicParsing -TimeoutSec 60
      tar -tzf $tgz | Out-Null
      if ($LASTEXITCODE -eq 0) { $ok = $true; break }
      Write-Host '  ...failed (not a valid archive)'
    } catch {
      Write-Host '  ...failed'
    }
  }
  if (-not $ok) { throw 'Every download source failed. Check your network, or clone the repo and run install.ps1 locally.' }
  tar -xzf $tgz -C $tmp
  $here = Join-Path $tmp 'quadruple-audit-main'
}

$candidates = @(
  (Join-Path $HOME '.claude\skills'),
  (Join-Path $HOME '.agents\skills')
)
$target = $args[0]
if (-not $target -and $env:QUADRUPLE_AUDIT_SKILLS_DIR) { $target = $env:QUADRUPLE_AUDIT_SKILLS_DIR }
$explicit = [bool]$target
if (-not $target) {
  foreach ($c in $candidates) {
    if (Test-Path $c) { $target = $c; break }
  }
}
if (-not $target) {
  $target = Join-Path $HOME '.agents\skills'
  Write-Host "No agent skills directory found; creating $target (works for ZCode and most agents)."
}
if (-not $explicit) {
  $skipped = @($candidates | Where-Object { (Test-Path $_) -and ($_ -ne $target) })
  if ($skipped.Count -gt 0) {
    Write-Host 'Also found other agent skill directories (not installed):'
    foreach ($s in $skipped) { Write-Host "  $s" }
    Write-Host "Run again with `$env:QUADRUPLE_AUDIT_SKILLS_DIR='<dir>' to install there too."
  }
}

$dest = Join-Path $target 'quadruple-audit'
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'examples\fixture') | Out-Null
Copy-Item (Join-Path $here 'SKILL.md'), (Join-Path $here 'README.md'), (Join-Path $here 'LICENSE'), (Join-Path $here 'CONTRIBUTING.md') -Destination $dest -Force
Copy-Item (Join-Path $here 'examples\sample-report.md'), (Join-Path $here 'examples\fixture-expected.md') -Destination (Join-Path $dest 'examples') -Force
Copy-Item (Join-Path $here 'examples\fixture\README.md'), (Join-Path $here 'examples\fixture\package.json'), (Join-Path $here 'examples\fixture\favorites.js'), (Join-Path $here 'examples\fixture\test.js') -Destination (Join-Path $dest 'examples\fixture') -Force

$version = (Select-String -Path (Join-Path $dest 'SKILL.md') -Pattern '^version:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
Write-Host "Installed quadruple-audit v$version into $dest"
Write-Host 'Invoke it with: /quadruple-audit <要检查的问题>'

if ($tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
