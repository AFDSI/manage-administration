
2025/09/28

discover-resources.ps1
Purpose:
  Emit a normalized JSON snapshot of the developer environment for variance planning.
Usage:
  pwsh -File .\discover-resources.ps1 `
    -OutFile .\env-baseline.json `
    -DevHomeOverride "E:\users\gigster\workspace" `
    -OwnerId "gigster" `
    -TimeoutSec 5 `
    -Verbose

