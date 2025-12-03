\** 2025/09/27

## pre flight


\*** Make PowerShell auto-load your generated profile ("profile.generated.ps1")
\** Path to the generated profile (adjust if your DEV_HOME differs)

```pwsh
$gen = "E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1"
```

\**Ensure your all-hosts profile exists

```pwsh
$prof = $PROFILE.CurrentUserAllHosts
if (!(Test-Path $prof)) { New-Item -ItemType File -Force -Path $prof | Out-Null }
```

\**Add a dot-source line once (idempotent)

```pwsh
$line = ". '$gen'"
if (-not (Select-String -Path $prof -SimpleMatch $line -Quiet)) {
  Add-Content -Path $prof -Value "`n$line"
}
Write-Host "Profile updated: $prof"
```

## set up

step A - discover and variance

```pwsh
cd E:\dev\profile-generator-gemini-?

& .\discover-resources.ps1

pwsh .\discover-resources.ps1

pwsh .\discover-resources.ps1 -OutFile .\env-baseline.json -DevHomeOverride "E:\users\gigster\workspace" -OwnerId "gigster"

options
-TimeoutSec 5
-Verbose

& .\discover-variance.ps1

& .\discover-variance.ps1 -BaselineJson .\env-baseline.json -ProfileYaml .\profile-values-update.yaml

& .\discover-variance-FIXED.ps1 -BaselineJson .\env-baseline.json -ProfileYaml .\profile-values-update.yaml

```

## clean up

step B - clean up

```pwsh
cd E:\dev\profile-generator-gemini-5

& .\cleanup-action.ps1 -ConfigPath .\cleanup-values.yaml

Start-Process pwsh -Verb RunAs -ArgumentList '-File .\cleanup-action.ps1 -ConfigPath .\cleanup-values.yaml'

```

## workflow

step 0 - create tree

```pwsh
cd E:\dev\profile-generator-gemini-2

Start-Job -ScriptBlock { .\show-directory-map.ps1 -Path 'E:\users' -DirectoryExclude 'node_modules' -FileInclude '*.js', '*.md' | Out-File 'show-directory-map.txt' -Encoding utf8 }

```

step 1 - generate values

```pwsh
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
cd E:\dev\profile-generator-gemini-7
& .\profile-generator.ps1 -ConfigPath ".\profile-values.yaml" -UnixTemplatesPath "E:\users\gigster\workspace\dev\profiles\templates"

. "/mnt/e/users/gigster/workspace/dev/profiles/bash/.bashrc.generated"

& .\profile-generator-update.ps1 -ConfigPath .\profile-values-update.yaml
# pwsh .\profile-generator.ps1 -ValuesPath .\profile-values.yaml -Apply

option
-ShowDebug
```

step 2 - Ensure PowerShell user profile **dot-sources** the generated file (once):

```pwsh
$gen = "E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1"
$prof = $PROFILE.CurrentUserAllHosts
if (!(Test-Path $prof)) { New-Item -ItemType File -Force -Path $prof | Out-Null }
$line = ". '$gen'"
if (-not (Select-String -Path $prof -SimpleMatch $line -Quiet)) {
  Add-Content -Path $prof -Value "`n$line"
}
Write-Host "Profile updated: $prof"
```

step 3 - Open a **new** PowerShell window and run:

```pwsh
$env:PROFILE_GENERATOR_LOADED
($env:PATH -split ';') | Select-Object -First 6
(Get-Command node).Source
(Get-Command python).Source
```

\** Expect PATH front (first 4) to be:

```
E:\users\gigster\workspace\dev\tools\python-bin
E:\users\gigster\workspace\dev\tools\nodejs
E:\users\gigster\workspace\dev\bin
E:\users\gigster\workspace\dev\tools
```

step 4 - debug

```pwsh
cd E:\dev\profile-generator-gemini
pwsh .\profile-debug.ps1
```

step 5 - variance

```pwsh
cd E:\dev\profile-generator-gemini
pwsh .\discover-variance.ps1 -BaselineJson .\env-baseline.json -ProfileYaml .\profile-values.yaml -OutDir .
```

### commands

\** Load profile

```pwsh
. E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1
```

\** Test functions

```pwsh
show_env
check_versions
show_commands

Get-Command node
Get-Command npm
Get-Command purgecss
Get-Command cleancss
```

\** explicitly call Windows tool

- powershell

```pwsh
where.exe node
where.exe npm
where.exe purgecss
where.exe cleancss
```

- unix shell

```bash
printenv
```

- powershell

```pwsh
gci Env:
```

\** npm should be next to node in E:\nodejs

```pwsh
Get-Command npm
```

\** confirm npm global prefix and that it’s on PATH

```pwsh
$prefix = (& npm config get prefix)
$prefix
($env:PATH -split ';') | Where-Object { $_ -ieq $prefix }
```

\** shims should be here (e.g. cleancss.cmd / purgecss.cmd)

```pwsh
Get-ChildItem -Name "$prefix\*.cmd"
```

\** do CLIs resolve?

```pwsh
Get-Command purgecss
Get-Command cleancss

node -v
npm -v

purgecss --version
cleancss --version

purgecss.cmd --version
cleancss.cmd --version
npm.cmd -v
```

