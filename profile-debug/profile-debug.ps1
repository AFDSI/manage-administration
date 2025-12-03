<#!
profile-debug.ps1
Purpose:
  - Reads the generated PowerShell profile
  - Reports PATH head / tool resolution
  - Flags unresolved tokens (${...}) or wrong order
Customize by user:
  E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1
TODO:
  write to a file in current directory: profile-debug.md
Usage:
  pwsh -ExecutionPolicy Bypass -File .\profile-debug.ps1
!#>

param(
  [string]$Generated = "E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1",
  [int]$Head = 8
)

function Info([string]$m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn([string]$m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err ([string]$m){ Write-Host "[ERROR] $m" -ForegroundColor Red }

if (-not (Test-Path -LiteralPath $Generated)) {
  Err "Generated profile not found: $Generated"
  exit 1
}

# 1) Static scan
$txt = Get-Content -Raw -LiteralPath $Generated

if ($txt -match '\$\{[^\}]+\}') {
  Warn "Found unresolved token(s) like \${...} in generated file."
}

if ($txt -match 'Prepend-PathOnce') {
  Err "Old PATH helper 'Prepend-PathOnce' still present; generator must emit Set-PathFront only."
}

# 2) Session checks (in this shell)
Info "PATH head (first $Head entries):"
($env:PATH -split ';') | Select-Object -First $Head | ForEach-Object { "  - $_" }

# Expect order:
#   python-bin, nodejs, dev\bin, dev\tools
$expected = @(
  "E:\users\gigster\workspace\dev\tools\python-bin",
  "E:\users\gigster\workspace\dev\tools\nodejs",
  "E:\users\gigster\workspace\dev\bin",
  "E:\users\gigster\workspace\dev\tools"
)

$headNow = ($env:PATH -split ';') | Where-Object { $_ } | Select-Object -First 4
if (@($headNow) -ne @($expected)) {
  Warn "PATH front is not in expected order."
  "  expected: $($expected -join ';')"
  "  actual  : $($headNow -join ';')"
} else {
  Info "PATH front order OK."
}

# 3) Tool resolution
try {
  $nodeSrc   = (Get-Command node -ErrorAction Stop).Source
  $pythonSrc = (Get-Command python -ErrorAction Stop).Source
  Info  "node   → $nodeSrc"
  Info  "python → $pythonSrc"
} catch {
  Warn "One or more tools not found on PATH. Ensure the generated profile is dot-sourced in `$PROFILE.CurrentUserAllHosts` and restart PowerShell."
}

# 4) Basic syntax validation (PowerShell)
try {
  [void][System.Management.Automation.Language.Parser]::ParseInput($txt,[ref]$null,[ref]$null)
  Info "Generated profile parses as valid PowerShell."
} catch {
  Err "PowerShell parse error in generated profile: $($_.Exception.Message)"
}
