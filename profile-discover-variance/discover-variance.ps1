[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$BaselineJson = ".\env-baseline.json",
  [Parameter(Mandatory)] [string]$ProfileYaml  = ".\profile-values-update.yaml",
  [string]$OutDir = "."
)

$ErrorActionPreference = 'Stop'

# --- helpers ----------------------------------------------------------------
function Require-Module($name) {
  if (-not (Get-Module -ListAvailable -Name $name)) {
    Write-Host "Module '$name' not found. Install with: Install-Module $name -Scope CurrentUser" -ForegroundColor Yellow
    throw "Missing module: $name"
  }
}

function Split-PathList([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return @() }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $out  = New-Object System.Collections.Generic.List[string]
  foreach ($p in ($s -split ';')) {
    $q = $p.Trim()
    if ($q -and $seen.Add($q)) { [void]$out.Add($q) }
  }
  return ,$out.ToArray()
}

function IsSecretName($name) { $name -match '(?i)(secret|token|key|password|passwd|pat|apikey|ghp_)' }

function Mask($v) {
  if ([string]::IsNullOrEmpty($v)) { return $v }
  $len = $v.Length
  if ($len -le 8) { return ('*' * $len) }
  return $v.Substring(0,[Math]::Min(4,$len)) + ('*' * [Math]::Max(0,$len-8)) + $v.Substring($len-4)
}

function IsWindowsPathLikeKey($k) { $k -match '^(PATH|PYTHONPATH|.+(_DIR|_PATH))$' }

# cheap-ish normalizer for “compare-ish” (don’t overfit; we only guide)
function Normalize-Value([string]$key, [string]$val) {
  if ($null -eq $val) { return "" }
  $v = $val.Trim()
  if (IsWindowsPathLikeKey $key) {
    # normalize slashes and drive-letter-safe separators
    $v = ($v -replace '/', '\')
    $v = [regex]::Replace($v, ':(?!\\)', ';')
    # collapse duplicate semicolons/spaces
    $v = ($v -split ';' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }) -join ';'
  }
  return $v
}

# build a map from YAML env + Windows overrides (values as strings)
function BuildDesiredEnv($yaml, $profileName = "development") {
  $out = @{}

  if ($yaml.env) {
    foreach ($k in $yaml.env.Keys) { $out[$k] = [string]$yaml.env[$k] }
  }
  # apply profile-specific overrides if present
  if ($yaml.profiles -and $yaml.profiles.$profileName -and $yaml.profiles.$profileName.windows) {
    foreach ($k in $yaml.profiles.$profileName.windows.Keys) {
      if ($k -eq 'node') { continue } # not an env var
      $out[$k] = [string]$yaml.profiles.$profileName.windows[$k]
    }
  }
  # legacy flat overrides section
  if ($yaml.env.platform_overrides -and $yaml.env.platform_overrides.windows) {
    foreach ($k in $yaml.env.platform_overrides.windows.Keys) {
      $out[$k] = [string]$yaml.env.platform_overrides.windows[$k]
    }
  }

  return $out
}

# --- load inputs ------------------------------------------------------------
Require-Module powershell-yaml

$baseline = Get-Content -Raw -Path $BaselineJson | ConvertFrom-Json
$yaml     = ConvertFrom-Yaml (Get-Content -Raw -Path $ProfileYaml)

# current (process) env from baseline
$procEnv = @{}
foreach ($name in $baseline.Env.Process.PSObject.Properties.Name) {
  $procEnv[$name] = [string]$baseline.Env.Process.$name
}

# desired env keys from YAML (+overrides)
$desired = BuildDesiredEnv -yaml $yaml

# desired "essential paths" on Windows (if present)
$essentialPaths = @()
if ($yaml.paths -and $yaml.paths.windows_primary) {
  $essentialPaths = @($yaml.paths.windows_primary | ForEach-Object {
    ([string]$_).Replace('/','\')
  })
}

# also consider npm prefix from baseline (if any)
$npmPrefix = $baseline.Tools.Node.NpmPrefix
if ($npmPrefix) { $essentialPaths += $npmPrefix }

# Node candidates from baseline & heuristic
$nodeCandidates = @()
$nodeCandidates += @($baseline.Tools.Node.KnownDirs) + 'C:\Program Files\nodejs','E:\nodejs','E:\node'
$nodeCandidates = $nodeCandidates | Where-Object { $_ } | Select-Object -Unique

# --- compute variance -------------------------------------------------------
$plan = [ordered]@{}
$plan.Meta = $baseline.Meta
$plan.Findings = [ordered]@{}

# Suspicious names
$invalidNames = @()
foreach ($n in $baseline.Anomalies.InvalidNames) { $invalidNames += $n }
$plan.Findings.InvalidNames = $invalidNames

# Secrets present (masked)
$secrets = @()
foreach ($s in $baseline.Anomalies.Secrets) {
  $secrets += [pscustomobject]@{ Name = $s.Name; Value = $s.Value }  # already masked
}
$plan.Findings.SecretsInEnv = $secrets

# PATH analysis
$currentPathList = Split-PathList $baseline.Env.Process.Path
$missingPaths = @()
foreach ($p in $essentialPaths) {
  if ($p -and ($currentPathList -notcontains $p)) { $missingPaths += $p }
}
$plan.Path = [ordered]@{
  Issues        = $baseline.PATH.Issues
  Duplicates    = $baseline.PATH.Duplicates
  MissingToPrepend = $missingPaths
}

# Node/npm status
$nodeFound = -not [string]::IsNullOrEmpty($baseline.Tools.Node.NodeExe)
$npmFound  = -not [string]::IsNullOrEmpty($baseline.Tools.Node.NpmCmd)
$prefixOnPath = $false
if ($npmPrefix) { $prefixOnPath = ($currentPathList -contains $npmPrefix) }
$plan.Node = [ordered]@{
  NodeFound     = $nodeFound
  NpmFound      = $npmFound
  NpmPrefix     = $npmPrefix
  PrefixOnPath  = $prefixOnPath
  KnownDirs     = $baseline.Tools.Node.KnownDirs
}

# Env var diffs (excluding PATH handled above)
$toCreate = @()
$toUpdate = @()
$toKeep   = @()

foreach ($k in $desired.Keys) {
  if ($k -eq 'PATH') { continue } # handled separately
  $want = Normalize-Value $k $desired[$k]
  $haveRaw = $procEnv[$k]
  $have = Normalize-Value $k $haveRaw

  if (-not $procEnv.ContainsKey($k)) {
    $toCreate += [pscustomobject]@{ Key=$k; Desired=$want }
    continue
  }

  if ($want -ne $have) {
    # keep original raw for context but show normalized comparison
    $toUpdate += [pscustomobject]@{ Key=$k; Current=$haveRaw; Desired=$want }
  } else {
    $toKeep += [pscustomobject]@{ Key=$k; Value=$haveRaw }
  }
}

$plan.Env = [ordered]@{
  Create = $toCreate
  Update = $toUpdate
  Keep   = $toKeep
}

# Recommendations (non-destructive first)
$reco = New-Object System.Collections.Generic.List[string]
if ($invalidNames) { $reco.Add("Remove invalid env names: " + ($invalidNames -join ', ')) }
if ($baseline.PATH.Issues -and $baseline.PATH.Issues.Count) { $reco.Add("Fix PATH separators (':' → ';', keep drive letters).") }
if ($missingPaths.Count) { $reco.Add("Prepend missing essential paths (process-scoped): " + ($missingPaths -join '; ')) }
if (-not $nodeFound -and -not $baseline.Tools.Node.KnownDirs) { $reco.Add("Install Node or add its directory to PATH (User).") }
if ($npmPrefix -and -not $prefixOnPath) { $reco.Add("Add npm prefix to PATH: $npmPrefix") }
if ($secrets.Count) { $reco.Add("Rotate / move secrets from env to a vault; avoid exporting tokens in profiles.") }
$plan.Recommendations = $reco

# --- output -----------------------------------------------------------------
$outPlanJson = Join-Path $OutDir 'env-plan.json'
$outPlanMd   = Join-Path $OutDir 'env-plan.md'

$plan | ConvertTo-Json -Depth 6 | Out-File -Encoding UTF8 $outPlanJson

# small Markdown summary
$md = @()
$md += "# Environment Plan"
$md += ""
$md += "## Findings"
if (@($invalidNames).Count) {
  $md += "* Invalid env names: " + ((@($invalidNames) | ForEach-Object { "``$($_)``" }) -join ', ')
}
if ($secrets.Count) { $md += "* Secrets present in env (**masked**). Rotate & remove from profile." }
if ($baseline.PATH.Duplicates.Count) { $md += "* PATH duplicates: " + ((@($baseline.PATH.Duplicates) | ForEach-Object { "``$($_)``" }) -join ', ') }
if ($baseline.PATH.Issues.Count)     { $md += "* PATH issues: " + ((@($baseline.PATH.Issues) | ForEach-Object { "``$($_)``" }) -join ', ') }
$md += ""
$md += "## PATH"
$md += "* Missing (to prepend, process-scoped):"
if ($missingPaths.Count) { $missingPaths | ForEach-Object { $md += "  - ``$_``" } } else { $md += "  - *(none)*" }
$md += ""
$md += "## Env Vars"
$md += "* Create:"
if ($toCreate.Count) { $toCreate | ForEach-Object { $md += "  - ``$($_.Key)`` = ``$($_.Desired)``" } } else { $md += "  - *(none)*" }
$md += "* Update:"
if ($toUpdate.Count) { $toUpdate | ForEach-Object { $md += "  - ``$($_.Key)``" } } else { $md += "  - *(none)*" }
$md += "* Keep:"
if ($toKeep.Count)   { $toKeep   | ForEach-Object { $md += "  - ``$($_.Key)``" } } else { $md += "  - *(none)*" }
$md += ""
$md += "## Node/npm"
$md += "* Node found: $nodeFound"
$md += "* npm found: $npmFound"
$md += "* npm prefix: ``$npmPrefix`` (on PATH: $prefixOnPath)"
$md += ""
$md += "## Recommendations"
if ($reco.Count) { $reco | ForEach-Object { $md += "* $_" } } else { $md += "* *(none)*" }

$md -join "`r`n" | Out-File -Encoding UTF8 $outPlanMd

Write-Host "Wrote $outPlanJson and $outPlanMd" -ForegroundColor Green
