<# 
Discover-DevResources.v2.ps1  (patched with timeouts & progress)
Purpose: Emit a normalized JSON snapshot of the developer environment for variance planning.
Usage:
  pwsh -File .\Discover-DevResources.v2.ps1 `
    -OutFile .\env-baseline.json `
    -DevHomeOverride "E:\users\gigster\workspace" `
    -OwnerId "gigster" `
    -TimeoutSec 5 `
    -Verbose
#>

[CmdletBinding()]
param(
  [string]$OutFile = ".\env-baseline.json",
  [string]$DevHomeOverride,
  [string]$OwnerId,
  [int]$TimeoutSec = 5
)

$ErrorActionPreference = "Stop"

Write-Verbose "Starting discovery with TimeoutSec=$TimeoutSec"

function Split-PathList([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return @() }
  return $s -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Which([string]$cmd) {
  try {
    $p = Get-Command $cmd -ErrorAction Stop
    return $p.Source
  } catch { return $null }
}

function Run-Cmd([string]$exe, [string[]]$args, [int]$timeoutSec) {
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $exe
    $psi.Arguments = ($args -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
      try { $p.Kill() } catch {}
      return @{ code = 124; out = ""; err = "timeout after ${timeoutSec}s" }
    }
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    return @{ code = $p.ExitCode; out = $out.Trim(); err = $err.Trim() }
  } catch {
    return @{ code = -1; out = ""; err = $_.Exception.Message }
  }
}

# --- Surface detection ---
$IsWSL = $false
if ($IsLinux -and $env:WSL_DISTRO_NAME) { $IsWSL = $true }

$surface = if ($IsWindows) { "windows_native" } elseif ($IsWSL) { "wsl" } elseif ($IsMacOS) { "mac" } else { "unknown" }
Write-Verbose "Surface=$surface"

# --- OwnerId resolution ---
if (-not $OwnerId) {
  if ($IsWindows) { $OwnerId = $env:USERNAME }
  elseif ($IsWSL -or $IsMacOS) { $OwnerId = (whoami).Split('\')[-1] }
  else { $OwnerId = $env:USERNAME }
}
$OwnerId = $OwnerId.ToLowerInvariant()
Write-Verbose "OwnerId=$OwnerId"

# --- DEV_HOME resolution ---
switch ($surface) {
  "windows_native" { $defaultDevHome = "E:\users\{0}\workspace" -f $OwnerId }
  "wsl"            { $defaultDevHome = "/mnt/e/users/{0}/workspace" -f $OwnerId }
  "mac"            { $defaultDevHome = "/Users/{0}/workspace" -f $OwnerId }
  default          { $defaultDevHome = $env:HOME }
}
$DEV_HOME = if ($DevHomeOverride) { $DevHomeOverride } else { $defaultDevHome }
Write-Verbose "DEV_HOME=$DEV_HOME"

# --- Paths-of-interest under DEV_HOME ---
$DEV_BIN   = Join-Path $DEV_HOME ("dev{0}bin" -f [IO.Path]::DirectorySeparatorChar)
$DEV_TOOLS = Join-Path $DEV_HOME ("dev{0}tools" -f [IO.Path]::DirectorySeparatorChar)
$NODE_SYM  = Join-Path $DEV_HOME ("dev{0}tools{0}nodejs" -f [IO.Path]::DirectorySeparatorChar)

# --- PATH analysis ---
$pathItems = Split-PathList $env:PATH
$dups = $pathItems | Group-Object { $_.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
$hasDevBin    = $pathItems -contains $DEV_BIN
$hasDevTools  = $pathItems -contains $DEV_TOOLS
$hasNodeSym   = $pathItems -contains $NODE_SYM

# --- Node (manager & version) ---
Write-Verbose "Checking Node"
$nodeWhere = Which "node"
$nodeVer   = if ($nodeWhere) { (Run-Cmd "node" @("--version") $TimeoutSec).out } else { "" }
$nvmHome   = $env:NVM_HOME
$nvmLink   = $env:NVM_SYMLINK
$nvmSettings = $null
try {
  if ($nvmHome -and (Test-Path -LiteralPath (Join-Path $nvmHome "settings.txt"))) {
    $nvmSettings = Get-Content -LiteralPath (Join-Path $nvmHome "settings.txt") -ErrorAction Ignore
  }
} catch {}

# --- Python (manager & version) ---
Write-Verbose "Checking Python"
$pyWhere  = (Which "python") ?? $null
$pyVerOut = ""
if ($pyWhere) {
  $r = Run-Cmd "python" @("--version") $TimeoutSec
  $pyVerOut = if ($r.code -eq 124) { "" } else { $r.out }
}
$uvPath   = Join-Path $DEV_TOOLS "uv.exe"
$uvExists = Test-Path -LiteralPath $uvPath

# --- WSL details (if applicable) ---
$wslInfo = $null
if ($IsWindows) {
  Write-Verbose "Checking WSL"
  try {
    $lst = Run-Cmd "wsl.exe" @("-l","-q") $TimeoutSec
    $distros = @()
    if ($lst.code -ne 124 -and $lst.out) {
      $distros = $lst.out -split "`r?`n" | Where-Object { $_ } | ForEach-Object { $_.Trim() }
    }
    $def = ""
    $lv  = Run-Cmd "wsl.exe" @("-l","-v") $TimeoutSec
    if ($lv.code -ne 124 -and $lv.out) {
      $def = ($lv.out -split "`r?`n" | Select-String '\*' | ForEach-Object { ($_ -split '\s+')[1] }) -as [string]
    }
    $metaFlag = $false
    if ($def) {
      $cat = Run-Cmd "wsl.exe" @("-d", $def, "cat", "/etc/wsl.conf") $TimeoutSec
      if ($cat.code -ne 124 -and $cat.out) { $metaFlag = ($cat.out -match 'options\s*=\s*".*metadata.*"') }
    }
    $wslInfo = @{
      Distros   = $distros
      Default   = $def
      Mounts    = @(@{ path="/mnt/e"; flags=@("metadata"); present=$metaFlag })
    }
  } catch {
    $wslInfo = $null
  }
}

# --- Secrets path ---
$secretsPath = if ($IsWindows) { Join-Path $env:USERPROFILE ".env.secrets" }
elseif ($IsWSL -or $IsMacOS) { "$HOME/.env.secrets" }
else { "$HOME/.env.secrets" }
$secretsPresent = Test-Path -LiteralPath $secretsPath

# --- Build result JSON ---
$result = [ordered]@{
  surface  = $surface
  owner_id = $OwnerId
  dev_home = $DEV_HOME
  paths = @{
    dev_bin       = $DEV_BIN
    dev_tools     = $DEV_TOOLS
    dev_node_symlink = $NODE_SYM
  }
  path_check = @{
    has_dev_bin      = $hasDevBin
    has_dev_tools    = $hasDevTools
    has_node_symlink = $hasNodeSym
    duplicates       = $dups
  }
  tools = @{
    node = @{
      present      = [bool]$nodeWhere
      version      = $nodeVer
      where        = $nodeWhere
      manager      = if ($nvmHome) { "nvm-windows" } elseif ($surface -eq "mac" -or $surface -eq "wsl") { "nvm?" } else { $null }
      nvm_home     = $nvmHome
      nvm_symlink  = $nvmLink
      nvm_settings = $nvmSettings
    }
    python = @{
      present      = [bool]$pyWhere
      version      = $pyVerOut
      where        = $pyWhere
      manager      = if ($uvExists) { "uv" } elseif ($pyWhere -and $IsWindows) { "msi?" } elseif ($surface -eq "mac" -or $surface -eq "wsl") { "pyenv?" } else { $null }
      uv_present   = $uvExists
      uv_path      = if ($uvExists) { $uvPath } else { $null }
    }
    git    = @{
      present      = [bool](Which "git")
      version      = (Run-Cmd "git" @("--version") $TimeoutSec).out
      where        = (Which "git")
    }
    awscli = @{
      present      = [bool](Which "aws")
      version      = (Run-Cmd "aws" @("--version") $TimeoutSec).out
      where        = (Which "aws")
    }
    netlify = @{
      present      = [bool](Which "netlify")
      version      = (Run-Cmd "netlify" @("--version") $TimeoutSec).out
      where        = (Which "netlify")
    }
  }
  wsl = $wslInfo
  secrets = @{
    path    = $secretsPath
    present = $secretsPresent
  }
  meta = @{
    host    = $env:COMPUTERNAME
    user    = $env:USERNAME
    time_utc= (Get-Date).ToUniversalTime().ToString('o')
    shell   = $PSVersionTable.PSEdition + " " + $PSVersionTable.PSVersion.ToString()
  }
}

# --- Write JSON ---
try {
  ($result | ConvertTo-Json -Depth 6) | Out-File -LiteralPath $OutFile -Encoding UTF8
  Write-Host ("Discovery written to {0}" -f $OutFile) -ForegroundColor Green
} catch {
  Write-Host ("Failed to write discovery file: {0}" -f $_.Exception.Message) -ForegroundColor Red
  exit 1
}
