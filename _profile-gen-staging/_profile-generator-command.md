
cd E:\users\gigster\workspace\dev\profiles\_generator

pwsh -NoProfile -ExecutionPolicy Bypass -File .\profile-build.ps1 `
    -ConfigPath .\profile-values.yaml `
    -HelpersPath .\profile-helpers-en.yaml `
    -UnixTemplatesPath .\templates

