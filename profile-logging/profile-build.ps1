<#
.SYNOPSIS
    Profile Generator v16.0 - Refactored for maintainability
.DESCRIPTION
    Generates platform-specific shell profiles from YAML configuration.
    Improvements:
    - Centralized path conversion
    - Template files read from disk (not embedded)
    - Enhanced validation
    - Better error handling
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $true)]
    [string]$UnixTemplatesPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# PATH CONVERSION UTILITIES
# ============================================================================

function Convert-PathForWSL {
    <#
    .SYNOPSIS
        Converts Windows path to WSL path format
    .EXAMPLE
        Convert-PathForWSL "E:\users\gigster\workspace" 
        Returns: /mnt/e/users/gigster/workspace
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )
    
    # Normalize to forward slashes
    $normalized = $WindowsPath.Replace('\', '/')
    
    # Convert drive letter: E:/ -> /mnt/e/
    if ($normalized -match '^([A-Za-z]):\/(.*)$') {
        $drive = $matches[1].ToLower()
        $rest = $matches[2]
        return "/mnt/$drive/$rest"
    }
    
    return $normalized
}

function Convert-PathToWindows {
    <#
    .SYNOPSIS
        Converts WSL path to Windows path format
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WSLPath
    )
    
    if ($WSLPath -match '^/mnt/([a-z])/(.*)$') {
        $drive = $matches[1].ToUpper()
        $rest = $matches[2].Replace('/', '\')
        return "${drive}:\$rest"
    }
    
    return $WSLPath.Replace('/', '\')
}

# ============================================================================
# VALIDATION UTILITIES
# ============================================================================

function Test-Prerequisites {
    param(
        [string]$ConfigPath,
        [string]$UnixTemplatesPath
    )
    
    Write-Host "`n=== Validating Prerequisites ===" -ForegroundColor Cyan
    
    # Check config file
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    Write-Host "  [OK] Config file found" -ForegroundColor Green
    
    # Check templates directory
    if (-not (Test-Path $UnixTemplatesPath)) {
        throw "Unix templates directory not found: $UnixTemplatesPath"
    }
    Write-Host "  [OK] Templates directory found" -ForegroundColor Green
    
    # Check for required template files
    $requiredTemplates = @('unix_builder.sh', 'unix_functions.sh')
    foreach ($template in $requiredTemplates) {
        $templatePath = Join-Path $UnixTemplatesPath $template
        if (-not (Test-Path $templatePath)) {
            throw "Required template not found: $templatePath"
        }
    }
    Write-Host "  [OK] All template files found" -ForegroundColor Green
    
    # Check for powershell-yaml module
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        Write-Host "  [INFO] Installing powershell-yaml module..." -ForegroundColor Yellow
        Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Repository PSGallery -Force
    }
    Write-Host "  [OK] PowerShell YAML module available" -ForegroundColor Green
    
    # Check WSL availability
    try {
        $wslTest = wsl.exe -d Debian -e echo "test" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "WSL Debian check failed. Unix profile generation may fail."
        } else {
            Write-Host "  [OK] WSL Debian is accessible" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Could not test WSL: $_"
    }
    
    Write-Host ""
}

# ============================================================================
# CONFIGURATION UTILITIES
# ============================================================================

function Resolve-ConfigVariables {
    <#
    .SYNOPSIS
        Recursively resolves ${variable.path} references in config
    #>
    param($Node, $Root)
    
    if ($null -eq $Node) { 
        return $null 
    }
    elseif ($Node -is [System.Collections.IDictionary]) {
        $dict = @{}
        foreach ($key in $Node.Keys) {
            $dict[$key] = Resolve-ConfigVariables -Node $Node[$key] -Root $Root
        }
        return $dict
    }
    elseif ($Node -is [System.Collections.IList]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Node) {
            $list.Add((Resolve-ConfigVariables -Node $item -Root $Root))
        }
        return $list
    }
    elseif ($Node -is [string]) {
        $resolvedString = $Node
        $pattern = '\$\{(.*?)\}'
        $maxIterations = 10
        $i = 0
        
        while (($i++ -lt $maxIterations) -and ([regex]::IsMatch($resolvedString, $pattern))) {
            $match = [regex]::Match($resolvedString, $pattern)
            $placeholder = $match.Groups[0].Value
            $variablePath = $match.Groups[1].Value
            
            try {
                $value = Invoke-Expression -Command "`$Root.$variablePath"
                if ($null -ne $value) {
                    $resolvedString = $resolvedString.Replace($placeholder, $value)
                }
                else {
                    Write-Warning "Could not resolve variable: $placeholder"
                    break
                }
            }
            catch {
                Write-Warning "Error resolving variable: $placeholder - $_"
                break
            }
        }
        return $resolvedString
    }
    else {
        return $Node
    }
}

function Repair-YamlStructure {
    <#
    .SYNOPSIS
        Ensures sections are always arrays (fixes YAML parser quirk)
    #>
    param($ConfigObject)
    
    $references = @(
        $ConfigObject.interface.command_reference,
        $ConfigObject.interface.examples_reference
    )
    
    foreach ($ref in $references) {
        # Fix default sections
        if ($null -ne $ref.default -and $null -ne $ref.default.PSObject.Properties['sections']) {
            if ($ref.default.sections -isnot [array]) {
                $ref.default.sections = @($ref.default.sections)
            }
        }
        
        # Fix mode-specific sections
        if ($null -ne $ref.modes) {
            foreach ($modeKey in $ref.modes.PSObject.Properties.Name) {
                $mode = $ref.modes.$modeKey
                if ($null -ne $mode -and $null -ne $mode.PSObject.Properties['sections']) {
                    if ($mode.sections -isnot [array]) {
                        $mode.sections = @($mode.sections)
                    }
                }
            }
        }
    }
    
    return $ConfigObject
}

# ============================================================================
# POWERSHELL PROFILE GENERATORS
# ============================================================================

function Generate-Header {
    param([string]$ConfigPath)
    
    return @"
# ============================================================================
# GENERATED FILE - DO NOT EDIT MANUALLY
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Source: $ConfigPath
# ============================================================================

"@
}

function Generate-InitializeDevEnvironment {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    
    [void]$sb.AppendLine("function Initialize-DevEnvironment {")
    [void]$sb.AppendLine("    Write-Host 'Initializing portable development environment...' -ForegroundColor Yellow")
    [void]$sb.AppendLine("    `$env:USERNAME = `"$($config.env.USERNAME)`"")
    
    $nodeOptions = $config.env.NODE_OPTIONS
    [void]$sb.AppendLine("    `$env:NODE_OPTIONS = '$nodeOptions'")
    [void]$sb.AppendLine("    `$env:DEV_HOME = `"$($config.dev_home.win)`"")
    
    # Build path entries
    [void]$sb.AppendLine("    `$cdePathEntries = @(")
    $config.paths.win.prepend | ForEach-Object {
        [void]$sb.AppendLine("        '$_'")
    }
    [void]$sb.AppendLine("    )")
    
    # Update PATH
    [void]$sb.AppendLine("    `$existingPathArray = `$env:PATH -split ';' | Where-Object { `$_.Trim() -and `$cdePathEntries -notcontains `$_ }")
    [void]$sb.AppendLine("    `$env:PATH = (`$cdePathEntries + `$existingPathArray) -join ';'")
    [void]$sb.AppendLine("    Write-Host 'Environment is ready.' -ForegroundColor Green")
    [void]$sb.AppendLine("}")
    
    return $sb.ToString()
}

function Generate-Aliases {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("`n# --- CDE Aliases ---")
    
    if ($config.interface.aliases) {
        foreach ($alias in $config.interface.aliases) {
            [void]$sb.AppendLine("Set-Alias -Name $($alias.name) -Value $($alias.definition) -Description 'CDE Helper'")
        }
    }
    
    return $sb.ToString()
}

function Generate-ReferenceFunction {
    param(
        [string]$FunctionName,
        $ConfigNode
    )
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("function $FunctionName {")
    
    if (-not $ConfigNode) {
        [void]$sb.AppendLine("    Write-Host 'No content defined for this mode.'")
        [void]$sb.AppendLine("}")
        return $sb.ToString()
    }
    
    [void]$sb.AppendLine("    Write-Host `"`n$($ConfigNode.title)`" -ForegroundColor Cyan")
    [void]$sb.AppendLine("    Write-Host (`"$('=' * $ConfigNode.title.Length)`") -ForegroundColor Cyan")
    
    foreach ($section in $ConfigNode.sections) {
        [void]$sb.AppendLine("    Write-Host `"`n$($section.heading):`"")
        
        # Check for commands or examples using hashtable keys (YAML parses to hashtables)
        $hasCommands = ($section -is [hashtable] -and $section.ContainsKey('commands')) -or 
                       ($section.PSObject.Properties.Name -contains 'commands')
        $hasExamples = ($section -is [hashtable] -and $section.ContainsKey('examples')) -or 
                       ($section.PSObject.Properties.Name -contains 'examples')
        $hasParameters = ($section -is [hashtable] -and $section.ContainsKey('parameters')) -or 
                         ($section.PSObject.Properties.Name -contains 'parameters')
        
        if ($hasCommands -or $hasExamples) {
            $ItemKey = if ($hasCommands) { 'commands' } else { 'examples' }
            $NameProperty = if ($ItemKey -eq 'commands') { 'name' } else { 'title' }
            $ValueProperty = if ($ItemKey -eq 'commands') { 'description' } else { 'snippet' }
            
            foreach ($item in $section.$ItemKey) {
                $nameFormatted = "{0,-30}" -f $item.$NameProperty
                [void]$sb.AppendLine("    Write-Host `"  $nameFormatted - $($item.$ValueProperty)`"")
            }
        }
        elseif ($hasParameters) {
            [void]$sb.AppendLine("    Write-Host `"  Command:     $($section.command)`"")
            [void]$sb.AppendLine("    Write-Host `"  Description: $($section.description)`"")
            [void]$sb.AppendLine("    Write-Host `"  Parameters:`"")
            
            foreach ($param in $section.parameters) {
                $flagFormatted = "{0,-25}" -f $param.flag
                [void]$sb.AppendLine("    Write-Host `"    $flagFormatted - $($param.desc)`"")
            }
        }
    }
    
    [void]$sb.AppendLine("}")
    return $sb.ToString()
}

function Generate-ShowEnv {
    return @'
function show_env {
    Write-Host
    Write-Host "Windows Development Environment" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "Platform: Windows PowerShell 7"
    Write-Host "User: $($env:USERNAME)"
    Write-Host "Home: $($env:USERPROFILE)"
    Write-Host "Dev Home: $($env:DEV_HOME)"
    Write-Host "Node Options: $($env:NODE_OPTIONS)"
}
'@
}

function Generate-CheckVersions {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('function check_versions {')
    [void]$sb.AppendLine('    Write-Host "`nTool Version Check"')
    [void]$sb.AppendLine('    Write-Host "===================="')
    [void]$sb.AppendLine('    if (Get-Command node -ErrorAction SilentlyContinue) {')
    [void]$sb.AppendLine('        $nodeVer = node --version')
    [void]$sb.AppendLine('        Write-Host "   [OK] Node.js: $nodeVer"')
    [void]$sb.AppendLine('    } else {')
    [void]$sb.AppendLine('        Write-Host "   [X] Node.js: Not found."')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('    if (Get-Command python -ErrorAction SilentlyContinue) {')
    [void]$sb.AppendLine('        $pyVer = python --version')
    [void]$sb.AppendLine('        Write-Host "   [OK] Python: $pyVer"')
    [void]$sb.AppendLine('    } else {')
    [void]$sb.AppendLine('        Write-Host "   [X] Python: Not found. (Check toolchains in YAML)"')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('    Write-Host "`nEnvironment Variables:"')
    
    foreach ($item in $config.secure_env.required) {
        $key = $item.name
        [void]$sb.AppendLine("    if (`$env:$key -and `$env:$key.Trim()) { Write-Host `"   [OK] $key`: SET`" -ForegroundColor Green } else { Write-Host `"   [X] $key`: NOT SET`" -ForegroundColor Red }")
    }
    
    [void]$sb.AppendLine("}")
    return $sb.ToString()
}

function Generate-Prompt {
    param($config)
    
    $prompt = $config.interface.prompt_style
    return "`nfunction prompt { '$prompt' }`n"
}

# ============================================================================
# SECRETS MANAGEMENT
# ============================================================================

function Build-Secrets {
    param($config)
    
    Write-Host "`n=== Building Secrets Files ===" -ForegroundColor Cyan
    
    $sm = $config.secrets_management
    
    # Validate secrets script exists
    if (-not (Test-Path $sm.script_path)) {
        Write-Warning "Secrets script not found: $($sm.script_path)"
        Write-Warning "Skipping secrets build. Ensure secrets are managed separately."
        return
    }
    
    try {
        # Build Unix format (dotenv-export, skip empty)
        & $sm.script_path build -Out $sm.output_file_nix -Format 'dotenv-export' -SkipEmpty -ErrorAction Stop
        Write-Host "  [OK] Unix secrets built" -ForegroundColor Green
        
        # Build PowerShell format (dotenv, skip empty)
        & $sm.script_path build -Out $sm.output_file_ps -Format 'dotenv' -SkipEmpty -ErrorAction Stop
        Write-Host "  [OK] PowerShell secrets built" -ForegroundColor Green
    }
    catch {
        Write-Warning "Secrets build failed: $_"
        Write-Warning "Continuing without secrets..."
    }
}

# ============================================================================
# POWERSHELL PROFILE GENERATION
# ============================================================================

function Build-PowerShellProfile {
    param($config, $configPath)
    
    Write-Host "`n=== Generating PowerShell Profile ===" -ForegroundColor Cyan
    
    $profileContent = [System.Text.StringBuilder]::new()
    
    # Header
    [void]$profileContent.Append((Generate-Header $configPath))
    
    # Parameters
    [void]$profileContent.AppendLine("param(`n    [string]`$Mode = 'default'`n)`n")
    
    # Utility function for loading env files
    $importEnvFunction = @'
function Import-EnvFile {
    param([string]$Path)
    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and !$line.StartsWith("#")) {
                $parts = $line.Split("=", 2)
                if ($parts.Length -eq 2) {
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim()
                    if ($value -match "^['`"](.*)['`"]$") {
                        $value = $matches[1]
                    }
                    Set-Item -Path "env:\$key" -Value $value
                }
            }
        }
    } else {
        Write-Warning "Environment file not found at $Path"
    }
}
'@
    [void]$profileContent.AppendLine($importEnvFunction)
    [void]$profileContent.AppendLine("")

    # Core functions
    [void]$profileContent.Append((Generate-InitializeDevEnvironment $config))
    [void]$profileContent.Append((Generate-ShowEnv))
    [void]$profileContent.Append((Generate-CheckVersions $config))
    [void]$profileContent.Append((Generate-Aliases $config))
    [void]$profileContent.Append((Generate-Prompt $config))
    
    # Mode-specific profiles
    [void]$profileContent.AppendLine("`n# --- Specialized Profile Modes ---")
    [void]$profileContent.AppendLine("switch (`$Mode.ToLower()) {")
    
    # AWS Mode
    if ($config.interface.command_reference.modes.AWS) {
        [void]$profileContent.AppendLine("    'aws' {")
        
        $awsCommandsNode = $config.interface.command_reference.modes.AWS
        [void]$profileContent.Append((Generate-ReferenceFunction -FunctionName "Show-QuickReference" -ConfigNode $awsCommandsNode))
        
        $awsExamplesNode = $config.interface.examples_reference.modes.AWS
        [void]$profileContent.Append((Generate-ReferenceFunction -FunctionName "Show-Examples" -ConfigNode $awsExamplesNode))
        
        [void]$profileContent.AppendLine("    }")
    }
    
    # Default Mode
    [void]$profileContent.AppendLine("    default {")
    $defaultCommandsNode = $config.interface.command_reference.default
    [void]$profileContent.Append((Generate-ReferenceFunction -FunctionName "Show-QuickReference" -ConfigNode $defaultCommandsNode))
    
    $defaultExamplesNode = $config.interface.examples_reference.default
    [void]$profileContent.Append((Generate-ReferenceFunction -FunctionName "Show-Examples" -ConfigNode $defaultExamplesNode))
    [void]$profileContent.AppendLine("    }")
    
    [void]$profileContent.AppendLine("}")
    
    # Startup sequence
    [void]$profileContent.AppendLine("`n# --- CDE Startup Sequence ---")
    [void]$profileContent.AppendLine("Clear-Host")
    [void]$profileContent.AppendLine("Initialize-DevEnvironment")
    [void]$profileContent.AppendLine("`n# Load secrets for all modes (KISS approach)")
    [void]$profileContent.AppendLine("Import-EnvFile -Path `"$($config.secrets_management.output_file_ps)`"")
    [void]$profileContent.AppendLine("`nif (`$Mode.ToLower() -eq 'aws') {")
    [void]$profileContent.AppendLine("    Write-Host 'AWS mode activated.' -ForegroundColor Cyan")
    [void]$profileContent.AppendLine("}")
    [void]$profileContent.AppendLine("`nshow_env")
    [void]$profileContent.AppendLine("Write-Host `"`n$($config.interface.startup_footer)`" -ForegroundColor Yellow")
    
    # Write to file
    $outputPath = $config.profiles.windows.ps_out
    $outputDir = Split-Path $outputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    Set-Content -Path $outputPath -Value $profileContent.ToString() -Encoding UTF8
    Write-Host "  [OK] PowerShell profile written to: $outputPath" -ForegroundColor Green
}

# ============================================================================
# UNIX PROFILE GENERATION
# ============================================================================

function Sync-UnixBashrc {
    param($config)
    
    Write-Host "`n=== Synchronizing Unix .bashrc ===" -ForegroundColor Cyan
    
    $generatedProfileWinPath = $config.profiles.wsl.bash_out
    $generatedProfileWslPath = Convert-PathForWSL $generatedProfileWinPath
    
    $bashrcFixerScript = @"
#!/bin/bash
set -e
GENERATED_PROFILE_PATH="$generatedProfileWslPath"
BASHRC_PATH="`$HOME/.bashrc"

echo "--- Synchronizing .bashrc ---"
printf '%s\n' ". \"`$GENERATED_PROFILE_PATH\"" > "`$BASHRC_PATH"
echo "[OK] .bashrc synchronized to source: `$GENERATED_PROFILE_PATH"
"@
    
    try {
        $bashrcFixerScript.Replace("`r`n", "`n") | wsl.exe -d Debian -- bash -s
        Write-Host "  [OK] .bashrc synchronized" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to sync .bashrc: $_"
    }
}

function Build-UnixProfiles {
    param($config, $UnixTemplatesPath)
    
    Write-Host "`n=== Generating Unix Profiles ===" -ForegroundColor Cyan
    
    # Read unix_builder.sh template
    $unixBuilderPath = Join-Path $UnixTemplatesPath "unix_builder.sh"
    if (-not (Test-Path $unixBuilderPath)) {
        throw "Unix builder template not found: $unixBuilderPath"
    }
    
    # Prepare JSON payload for unix builder
    $secretsFileWsl = Convert-PathForWSL $config.secrets_management.output_file_nix

    $unixPayload = [PSCustomObject]@{
        interface = $config.interface
        secure_env = $config.secure_env
        bashOutPath = Convert-PathForWSL $config.profiles.wsl.bash_out
        zshOutPath = Convert-PathForWSL $config.profiles.wsl.zsh_out
        devHome = $config.dev_home.wsl
        secretsFile = $secretsFileWsl
        envUsername = $config.env.USERNAME
        envAmpProject = $config.env.AMP_DEV_PROJECT
        envNodeOptions = $config.env.NODE_OPTIONS
        navigation = $config.navigation.wsl
    }

    $jsonPayload = $unixPayload | ConvertTo-Json -Depth 10 -Compress
    $unixBuilderWslPath = Convert-PathForWSL $unixBuilderPath
    
    try {
        $jsonPayload | wsl.exe -d Debian -e bash "$unixBuilderWslPath"
        Write-Host "  [OK] Unix profiles generated" -ForegroundColor Green
    }
    catch {
        Write-Error "Unix profile generation failed: $_"
        throw
    }
}

function Harden-UnixProfiles {
    param($config)
    
    Write-Host "`n=== Hardening Unix Profiles (dos2unix) ===" -ForegroundColor Cyan
    
    $bashFileWsl = Convert-PathForWSL $config.profiles.wsl.bash_out
    $zshFileWsl = Convert-PathForWSL $config.profiles.wsl.zsh_out
    
    try {
        wsl.exe -d Debian -- dos2unix "$bashFileWsl" "$zshFileWsl" 2>&1 | Out-Null
        Write-Host "  [OK] Unix profiles cleaned with dos2unix" -ForegroundColor Green
    }
    catch {
        Write-Warning "dos2unix hardening failed: $_"
        Write-Warning "This may cause issues on WSL 1"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "   Profile Generator v16.0 (Claude)" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta
    
    # 1. Validate prerequisites
    Test-Prerequisites -ConfigPath $ConfigPath -UnixTemplatesPath $UnixTemplatesPath
    
    # 2. Load and resolve configuration
    Write-Host "=== Loading Configuration ===" -ForegroundColor Cyan
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    $configAbsPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
        $ConfigPath
    } else {
        Join-Path $scriptRoot $ConfigPath
    }
    
    Import-Module 'powershell-yaml'
    $rawConfig = Get-Content -Path $configAbsPath -Raw | ConvertFrom-Yaml
    $config = Resolve-ConfigVariables -Node $rawConfig -Root $rawConfig
    $config = Repair-YamlStructure -ConfigObject $config
    Write-Host "  [OK] Configuration loaded and resolved" -ForegroundColor Green
    
    # 3. Build secrets
    Build-Secrets -config $config
    
    # 4. Generate PowerShell profile
    Build-PowerShellProfile -config $config -configPath $configAbsPath
    
    # 5. Sync Unix .bashrc
    Sync-UnixBashrc -config $config
    
    # 6. Generate Unix profiles
    Build-UnixProfiles -config $config -UnixTemplatesPath $UnixTemplatesPath
    
    # 7. Harden Unix profiles for WSL 1
    Harden-UnixProfiles -config $config
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "   Profile Generation Complete!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    exit 0
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "   ERROR: Profile Generation Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Error $_
    Write-Host "`nStack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}