## change to source diectory
cd E:\users\gigster\workspace\dev\profiles\_generator

## Remove a “downloaded from internet” block on files
Unblock-File -Path .\profile-build.ps1
Get-ChildItem -Path . -Filter *.ps1 -Recurse | Unblock-File
Unblock-File -Path "E:\users\gigster\workspace\dev\profiles\_generator\templates\unix_builder.sh"

## Bypass policy for THIS session (doesn't change your machine)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

## run build

pwsh -NoProfile -ExecutionPolicy Bypass -File .\profile-build.ps1 -ConfigPath .\profile-values.yaml -HelpersPath .\profile-helpers-en.yaml -UnixTemplatesPath .\templates


# In Debian
source ~/.bashrc


* Quick verify (after saving changes)

Open a **new** PowerShell session and check:

$env:PROFILE_GENERATOR_LOADED              # shows an ISO timestamp

($env:PATH -split ';') | Select-Object -First 6

* Expect to see entries beginning with:
- E:\users\gigster\workspace\dev\tools\python-bin
- E:\users\gigster\workspace\dev\tools\nodejs
- E:\users\gigster\workspace\dev\bin
- E:\users\gigster\workspace\dev\tools

(Get-Command node).Source                 # -> E:\...\dev\tools\nodejs\node.exe
(Get-Command python).Source               # -> E:\...\dev\tools\python-bin\python.exe
python -V                                 # -> 3.13.x (or whichever you set default with uv)
