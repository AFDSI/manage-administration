<#
.SYNOPSIS
    Profile Generator v18.0 - UX Standardization & Platform Detection
.DESCRIPTION
    Generates platform-specific shell profiles from YAML configuration.
    New in v18.0:
    - Platform detection (Windows/WSL/MacOS)
    - Standardized UX output per ux-v3.csv specification
    - Mode-specific API status display
    - Function naming conventions (hyphens vs underscores)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $true)]
    [string]$HelpersPath,
    
    [Parameter(Mandatory = $true)]
    [string]$UnixTemplatesPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# SAFE PROPERTY ACCESS UTILITY
# ============================================================================

function Get-PropertyValue {
    <#
    .SYNOPSIS
        Safely access properties on objects that may be hashtables or PSCustomObjects
    .DESCRIPTION
        YAML parsing can create either hashtables or PSCustomObjects inconsistently.
        This function provides safe property access regardless of object type.
        Uses index notation to avoid conflicts with PowerShell reserved variables like $HOME.
    .EXAMPLE
        $enabled = Get-PropertyValue $mode 'enabled' $true
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Object,
        
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
        
        [Parameter(Mandatory = $false)]
        $Default = $null
    )
    
    if ($null -eq $Object) {
        return $Default
    }
    
    if ($Object -is [hashtable]) {
        if ($Object.ContainsKey($PropertyName)) {
            return $Object[$PropertyName]
        }
    }
    elseif ($null -ne $Object.PSObject.Properties[$PropertyName]) {
        # Use .Value to avoid dot notation with variable (prevents $HOME conflicts)
        return $Object.PSObject.Properties[$PropertyName].Value
    }
    
    return $Default
}

# ============================================================================
# PATH CONVERSION UTILITIES
# ============================================================================

function Convert-PathForWSL {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )
    
    $normalized = $WindowsPath.Replace('\', '/')
    
    if ($normalized -match '^([A-Za-z]):\/(.*)$') {
        $drive = $matches[1].ToLower()
        $rest = $matches[2]
        return "/mnt/$drive/$rest"
    }
    
    return $normalized
}

function Convert-PathToWindows {
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
        [string]$HelpersPath,
        [string]$UnixTemplatesPath
    )
    
    Write-Host "`n=== Validating Prerequisites ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    Write-Host "  [OK] Config file found" -ForegroundColor Green
    
    if (-not (Test-Path $HelpersPath)) {
        throw "Helper file not found: $HelpersPath"
    }
    Write-Host "  [OK] Helper file found" -ForegroundColor Green
    
    if (-not (Test-Path $UnixTemplatesPath)) {
        throw "Unix templates directory not found: $UnixTemplatesPath"
    }
    Write-Host "  [OK] Templates directory found" -ForegroundColor Green
    
    $requiredTemplates = @('unix_builder.sh', 'unix_functions.sh')
    foreach ($template in $requiredTemplates) {
        $templatePath = Join-Path $UnixTemplatesPath $template
        if (-not (Test-Path $templatePath)) {
            throw "Required template not found: $templatePath"
        }
    }
    Write-Host "  [OK] All template files found" -ForegroundColor Green
    
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        Write-Host "  [INFO] Installing powershell-yaml module..." -ForegroundColor Yellow
        Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Repository PSGallery -Force
    }
    Write-Host "  [OK] PowerShell YAML module available" -ForegroundColor Green
    
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

function Load-HelperConfiguration {
    param([string]$HelpersPath)
    
    Write-Host "=== Loading Helper Configuration ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $HelpersPath)) {
        throw "Helper file not found: $HelpersPath"
    }
    
    $helpersContent = Get-Content -Path $HelpersPath -Raw | ConvertFrom-Yaml
    Write-Host "  [OK] Helpers loaded from: $HelpersPath" -ForegroundColor Green
    
    return $helpersContent
}

# ============================================================================
# POWERSHELL PROFILE GENERATORS
# ============================================================================

function Generate-Header {
    param([string]$ConfigPath, [string]$HelpersPath)
    
    return @"
# ============================================================================
# GENERATED FILE - DO NOT EDIT MANUALLY
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Config: $ConfigPath
# Helpers: $HelpersPath
# Generator Version: 18.0
# ============================================================================

"@
}

function Generate-ModeLogic {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    
    # Parameter block for mode selection
    [void]$sb.AppendLine("# ============================================================================")
    [void]$sb.AppendLine("# MODE SELECTION")
    [void]$sb.AppendLine("# ============================================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("param(")
    [void]$sb.AppendLine("    [ValidateSet('Default', 'pwsh', 'aws', 'claude_code', 'google_cloud')]")
    [void]$sb.AppendLine("    [string]`$Mode = 'Default'")
    [void]$sb.AppendLine(")")
    [void]$sb.AppendLine("")
    
    # Mode initialization function
    [void]$sb.AppendLine("function Initialize-ModeEnvironment {")
    [void]$sb.AppendLine("    param([string]`$Mode)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    `$modeConfig = `$null")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    switch (`$Mode) {")
    
    # Add each mode
    foreach ($modeName in @('pwsh', 'aws', 'claude_code', 'google_cloud')) {
        # Safe property access for mode configuration
        $modeConfig = Get-PropertyValue $config.modes $modeName $null
        if ($null -eq $modeConfig) { continue }
        
        $enabled = Get-PropertyValue $modeConfig 'enabled' $true
        if (-not $enabled) { continue }
        
        $startupMsg = Get-PropertyValue $modeConfig 'startup_message' "[$modeName] Environment initialized"
        $color = Get-PropertyValue $modeConfig 'color' 'White'
        
        [void]$sb.AppendLine("        '$modeName' {")
        [void]$sb.AppendLine("            Write-Host `"$startupMsg`" -ForegroundColor $color")
        [void]$sb.AppendLine("        }")
    }
    
    [void]$sb.AppendLine("        default {")
    [void]$sb.AppendLine("            Write-Host `"[Default] Environment initialized`" -ForegroundColor White")
    [void]$sb.AppendLine("        }")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
    
    return $sb.ToString()
}

function Generate-ShowEnv {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    
    [void]$sb.AppendLine("function show-env {")
    [void]$sb.AppendLine("    # Display mode-specific startup message")
    [void]$sb.AppendLine("    if (`$Mode -and `$Mode -ne 'Default') {")
    [void]$sb.AppendLine("        `$modeConfig = `$null")
    [void]$sb.AppendLine("        switch (`$Mode) {")
    
    # Add mode-specific display logic
    foreach ($modeName in @('pwsh', 'aws', 'claude_code', 'google_cloud')) {
        # Safe property access for mode configuration
        $modeConfig = Get-PropertyValue $config.modes $modeName $null
        if ($null -eq $modeConfig) { continue }
        
        $enabled = Get-PropertyValue $modeConfig 'enabled' $true
        if (-not $enabled) { continue }
        
        $startupMsg = Get-PropertyValue $modeConfig 'startup_message' "[$modeName] Environment initialized"
        $color = Get-PropertyValue $modeConfig 'color' 'White'
        $showApiStatus = Get-PropertyValue $modeConfig 'show_api_status' $false
        
        [void]$sb.AppendLine("            '$modeName' {")
        [void]$sb.AppendLine("                Write-Host `"$startupMsg`" -ForegroundColor $color")
        
        # Add API status display if enabled
        if ($showApiStatus) {
            $requiredSecrets = Get-PropertyValue $modeConfig 'required_secrets' @()
            $secretsArray = @($requiredSecrets)
            
            if ($secretsArray.Count -gt 0) {
                [void]$sb.AppendLine("                # API Status")
                foreach ($secret in $secretsArray) {
                    [void]$sb.AppendLine("                if (`$env:$secret) {")
                    [void]$sb.AppendLine("                    Write-Host `"  [OK] $secret loaded`" -ForegroundColor Green")
                    [void]$sb.AppendLine("                } else {")
                    [void]$sb.AppendLine("                    Write-Host `"  [MISSING] $secret`" -ForegroundColor Red")
                    [void]$sb.AppendLine("                }")
                }
            }
        }
        
        [void]$sb.AppendLine("            }")
    }
    
    [void]$sb.AppendLine("        }")
    [void]$sb.AppendLine("        Write-Host `"`"")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    
    # Platform-specific display (Windows in this case)
    # CRITICAL: Use safe property access and avoid $home variable name (conflicts with $HOME)
    $platform = Get-PropertyValue $config 'platform' $null
    $platformWindows = if ($platform) { Get-PropertyValue $platform 'windows' $null } else { $null }
    
    $header = if ($platformWindows) { Get-PropertyValue $platformWindows 'header' 'Development Environment' } else { 'Development Environment' }
    $separator = if ($platformWindows) { Get-PropertyValue $platformWindows 'separator' '=============================' } else { '=============================' }
    $platformLabel = if ($platformWindows) { Get-PropertyValue $platformWindows 'platform_label' 'PowerShell' } else { 'PowerShell' }
    $homeDir = if ($platformWindows) { Get-PropertyValue $platformWindows 'home' '' } else { '' }  # ← Changed from $home to $homeDir
    
    $workspace = Get-PropertyValue $config.workspace 'win' ''
    $envVars = Get-PropertyValue $config 'env' $null
    $nodeOptions = if ($envVars) { Get-PropertyValue $envVars 'NODE_OPTIONS' '' } else { '' }
    
    $identity = Get-PropertyValue $config 'identity' $null
    $username = if ($identity) { Get-PropertyValue $identity 'owner_id' 'user' } else { 'user' }
    
    [void]$sb.AppendLine("    Write-Host `"$header`" -ForegroundColor Cyan")
    [void]$sb.AppendLine("    Write-Host `"$separator`" -ForegroundColor Cyan")
    [void]$sb.AppendLine("    Write-Host `"Platform: $platformLabel`" -ForegroundColor White")
    [void]$sb.AppendLine("    Write-Host `"User: $username`" -ForegroundColor White")
    [void]$sb.AppendLine("    Write-Host `"Home: $homeDir`" -ForegroundColor White")
    [void]$sb.AppendLine("    Write-Host `"Workspace: $workspace`" -ForegroundColor White")
    [void]$sb.AppendLine("    Write-Host `"Node Options: $nodeOptions`" -ForegroundColor White")
    [void]$sb.AppendLine("    Write-Host `"`"")
    
    # Hints - use PowerShell naming convention (hyphens)
    [void]$sb.AppendLine("    # Hints")
    $ux = Get-PropertyValue $config 'ux' $null
    if ($ux) {
        $hints = Get-PropertyValue $ux 'hints' $null
        if ($hints) {
            $powershellHints = Get-PropertyValue $hints 'powershell' @()
            $hintsArray = @($powershellHints)
            foreach ($hint in $hintsArray) {
                [void]$sb.AppendLine("    Write-Host `"$hint`" -ForegroundColor Yellow")
            }
        }
    }
    
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
    
    return $sb.ToString()
}

function Generate-InitializeDevEnvironment {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    
    # Safe property access for all config values
    $ux = Get-PropertyValue $config 'ux' $null
    $startup = if ($ux) { Get-PropertyValue $ux 'startup' $null } else { $null }
    $initMessage = if ($startup) { Get-PropertyValue $startup 'init_message' 'Initializing...' } else { 'Initializing...' }
    $readyMessage = if ($startup) { Get-PropertyValue $startup 'ready_message' 'Ready.' } else { 'Ready.' }
    
    $envVars = Get-PropertyValue $config 'env' $null
    $envUsername = if ($envVars) { Get-PropertyValue $envVars 'USERNAME' '' } else { '' }
    $nodeOptions = if ($envVars) { Get-PropertyValue $envVars 'NODE_OPTIONS' '' } else { '' }
    $uvCacheDir = if ($envVars) { Get-PropertyValue $envVars 'UV_CACHE_DIR' '' } else { '' }
    $uvToolDir = if ($envVars) { Get-PropertyValue $envVars 'UV_TOOL_DIR' '' } else { '' }
    $uvPythonDir = if ($envVars) { Get-PropertyValue $envVars 'UV_PYTHON_INSTALL_DIR' '' } else { '' }
    
    $workspace = Get-PropertyValue $config.workspace 'win' ''
    
    $paths = Get-PropertyValue $config 'paths' $null
    $pathsWin = if ($paths) { Get-PropertyValue $paths 'win' $null } else { $null }
    $pathsPrepend = if ($pathsWin) { Get-PropertyValue $pathsWin 'prepend' @() } else { @() }
    $pathsArray = @($pathsPrepend)
    
    [void]$sb.AppendLine("function Initialize-DevEnvironment {")
    [void]$sb.AppendLine("    Write-Host '$initMessage' -ForegroundColor Yellow")
    [void]$sb.AppendLine("    `$env:USERNAME = `"$envUsername`"")
    
    [void]$sb.AppendLine("    `$env:NODE_OPTIONS = '$nodeOptions'")
    [void]$sb.AppendLine("    `$env:WORKSPACE = `"$workspace`"")
    
    [void]$sb.AppendLine("    `$cdePathEntries = @(")
    for ($i = 0; $i -lt $pathsArray.Count; $i++) {
        $pathEntry = $pathsArray[$i]
        $comma = if ($i -lt $pathsArray.Count - 1) { "," } else { "" }
        [void]$sb.AppendLine("        `"$pathEntry`"$comma")
    }
    [void]$sb.AppendLine("    )")
    
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    `$existingPaths = `$env:PATH -split ';'")
    [void]$sb.AppendLine("    `$cleanedPaths = `$existingPaths | Where-Object { `$cdePathEntries -notcontains `$_ }")
    [void]$sb.AppendLine("    `$env:PATH = (`$cdePathEntries + `$cleanedPaths) -join ';'")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    `$env:UV_CACHE_DIR = `"$uvCacheDir`"")
    [void]$sb.AppendLine("    `$env:UV_TOOL_DIR = `"$uvToolDir`"")
    [void]$sb.AppendLine("    `$env:UV_PYTHON_INSTALL_DIR = `"$uvPythonDir`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    Write-Host '$readyMessage' -ForegroundColor Green")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
    
    return $sb.ToString()
}

function Generate-CheckVersions {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    
    [void]$sb.AppendLine("function check-versions {")
    [void]$sb.AppendLine("    Write-Host `"`n=== Tool Versions ===`" -ForegroundColor Cyan")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    # Node.js")
    [void]$sb.AppendLine("    try {")
    [void]$sb.AppendLine("        `$nodeVersion = node --version 2>&1")
    [void]$sb.AppendLine("        Write-Host `"Node.js: `$nodeVersion`" -ForegroundColor Green")
    [void]$sb.AppendLine("    } catch {")
    [void]$sb.AppendLine("        Write-Host `"Node.js: Not found`" -ForegroundColor Red")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    # Python")
    [void]$sb.AppendLine("    try {")
    [void]$sb.AppendLine("        `$pythonVersion = python --version 2>&1")
    [void]$sb.AppendLine("        Write-Host `"Python: `$pythonVersion`" -ForegroundColor Green")
    [void]$sb.AppendLine("    } catch {")
    [void]$sb.AppendLine("        Write-Host `"Python: Not found`" -ForegroundColor Red")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    # UV")
    [void]$sb.AppendLine("    try {")
    [void]$sb.AppendLine("        `$uvVersion = uv --version 2>&1")
    [void]$sb.AppendLine("        Write-Host `"UV: `$uvVersion`" -ForegroundColor Green")
    [void]$sb.AppendLine("    } catch {")
    [void]$sb.AppendLine("        Write-Host `"UV: Not found`" -ForegroundColor Red")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    # Git")
    [void]$sb.AppendLine("    try {")
    [void]$sb.AppendLine("        `$gitVersion = git --version 2>&1")
    [void]$sb.AppendLine("        Write-Host `"Git: `$gitVersion`" -ForegroundColor Green")
    [void]$sb.AppendLine("    } catch {")
    [void]$sb.AppendLine("        Write-Host `"Git: Not found`" -ForegroundColor Red")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    
    # Add Claude Code version check if enabled
    $claudeCodeConfig = Get-PropertyValue $config.modes 'claude_code' $null
    if ($null -ne $claudeCodeConfig) {
        $claudeEnabled = Get-PropertyValue $claudeCodeConfig 'enabled' $false
        $versionCheck = Get-PropertyValue $claudeCodeConfig 'version_check' $null
        
        if ($claudeEnabled -and $null -ne $versionCheck) {
            $command = Get-PropertyValue $versionCheck 'command' 'claude --version'
            $name = Get-PropertyValue $versionCheck 'name' 'Claude Code'
            
            [void]$sb.AppendLine("    # $name")
            [void]$sb.AppendLine("    try {")
            [void]$sb.AppendLine("        `$claudeVersion = $command 2>&1")
            [void]$sb.AppendLine("        Write-Host `"${name}: `$claudeVersion`" -ForegroundColor Green")
            [void]$sb.AppendLine("    } catch {")
            [void]$sb.AppendLine("        Write-Host `"${name}: Not found`" -ForegroundColor Red")
            [void]$sb.AppendLine("    }")
            [void]$sb.AppendLine("")
        }
    }
    
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
    
    return $sb.ToString()
}

function Generate-TopicCommands {
    param($helpers)
    
    $sb = [System.Text.StringBuilder]::new()
    
    [void]$sb.AppendLine("function show-commands {")
    [void]$sb.AppendLine("    param([string]`$Topic)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    if (-not `$Topic) {")
    [void]$sb.AppendLine("        Write-Host `"`nAvailable topics: aws, node, python, git`" -ForegroundColor Yellow")
    [void]$sb.AppendLine("        Write-Host `"Usage: Show-Commands <topic>`n`" -ForegroundColor Yellow")
    [void]$sb.AppendLine("        return")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    switch (`$Topic.ToLower()) {")
    
    # Generate for each topic
    foreach ($topic in @('aws', 'node', 'python', 'git')) {
        # Safe property access using Get-PropertyValue
        $helpersObj = Get-PropertyValue $helpers 'helpers' $null
        $topicHelpers = if ($helpersObj) { Get-PropertyValue $helpersObj $topic $null } else { $null }
        $helperData = if ($topicHelpers) { Get-PropertyValue $topicHelpers 'powershell' $null } else { $null }
        
        if ($helperData) {
            [void]$sb.AppendLine("        '$topic' {")
            [void]$sb.AppendLine("            Write-Host `"`n=== $($helperData.title) ===`" -ForegroundColor Cyan")
            
            foreach ($section in $helperData.sections) {
                [void]$sb.AppendLine("            Write-Host `"`n$($section.heading):`" -ForegroundColor Yellow")
                foreach ($cmd in $section.commands) {
                    [void]$sb.AppendLine("            Write-Host `"  $($cmd.name)`" -ForegroundColor White")
                    [void]$sb.AppendLine("            Write-Host `"    $($cmd.description)`" -ForegroundColor Gray")
                }
            }
            
            [void]$sb.AppendLine("        }")
        }
    }
    
    [void]$sb.AppendLine("        default {")
    [void]$sb.AppendLine("            Write-Host `"`nUnknown topic: `$Topic`" -ForegroundColor Red")
    [void]$sb.AppendLine("            Write-Host `"Available topics: aws, node, python, git`n`" -ForegroundColor Yellow")
    [void]$sb.AppendLine("        }")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
    
    return $sb.ToString()
}

function Generate-TopicExamples {
    param($helpers)
    
    $sb = [System.Text.StringBuilder]::new()
    
    [void]$sb.AppendLine("function show-examples {")
    [void]$sb.AppendLine("    param([string]`$Topic)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    if (-not `$Topic) {")
    [void]$sb.AppendLine("        Write-Host `"`nAvailable topics: aws, node, python, git`" -ForegroundColor Yellow")
    [void]$sb.AppendLine("        Write-Host `"Usage: Show-Examples <topic>`n`" -ForegroundColor Yellow")
    [void]$sb.AppendLine("        return")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    switch (`$Topic.ToLower()) {")
    
    # Generate for each topic
    foreach ($topic in @('aws', 'node', 'python', 'git')) {
        # Safe property access using Get-PropertyValue
        $examplesObj = Get-PropertyValue $helpers 'examples' $null
        $topicExamples = if ($examplesObj) { Get-PropertyValue $examplesObj $topic $null } else { $null }
        $exampleData = if ($topicExamples) { Get-PropertyValue $topicExamples 'powershell' $null } else { $null }
        
        if ($exampleData) {
            [void]$sb.AppendLine("        '$topic' {")
            [void]$sb.AppendLine("            Write-Host `"`n=== $($exampleData.title) ===`" -ForegroundColor Cyan")
            
            foreach ($section in $exampleData.sections) {
                [void]$sb.AppendLine("            Write-Host `"`n$($section.heading):`" -ForegroundColor Yellow")
                foreach ($example in $section.examples) {
                    [void]$sb.AppendLine("            Write-Host `"  $($example.title):`" -ForegroundColor White")
                    [void]$sb.AppendLine("            Write-Host `"    $($example.snippet)`" -ForegroundColor Gray")
                }
            }
            
            [void]$sb.AppendLine("        }")
        }
    }
    
    [void]$sb.AppendLine("        default {")
    [void]$sb.AppendLine("            Write-Host `"`nUnknown topic: `$Topic`" -ForegroundColor Red")
    [void]$sb.AppendLine("            Write-Host `"Available topics: aws, node, python, git`n`" -ForegroundColor Yellow")
    [void]$sb.AppendLine("        }")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
    
    return $sb.ToString()
}

function Generate-Aliases {
    param($config)
    
    $sb = [System.Text.StringBuilder]::new()
    
    [void]$sb.AppendLine("# ============================================================================")
    [void]$sb.AppendLine("# NAVIGATION & SHORTCUTS")
    [void]$sb.AppendLine("# ============================================================================")
    [void]$sb.AppendLine("")
    
    # Navigation shortcuts as functions (not aliases to avoid $HOME conflict)
    [void]$sb.AppendLine("# Navigation Functions")
    
    # Get navigation keys safely
    $navWin = Get-PropertyValue $config.navigation 'win' $null
    if ($null -ne $navWin) {
        $navKeys = if ($navWin -is [hashtable]) {
            $navWin.Keys
        } else {
            $navWin.PSObject.Properties.Name
        }
        
        foreach ($shortcutName in $navKeys) {
            # Use Get-PropertyValue to safely get the path
            $targetPath = Get-PropertyValue $navWin $shortcutName ""
            
            if ($targetPath) {
                # Generate function instead of alias (aliases can't use script blocks)
                [void]$sb.AppendLine("function $shortcutName { Set-Location '$targetPath' }")
            }
        }
    }
    
    [void]$sb.AppendLine("")
    
    # No aliases or wrappers needed - functions use lowercase names directly
    
    return $sb.ToString()
}

function Generate-Prompt {
    param($config)
    
    # Safe property access
    $interface = Get-PropertyValue $config 'interface' $null
    $promptStyle = if ($interface) { Get-PropertyValue $interface 'prompt_style' '> ' } else { '> ' }
    
    return @"
# ============================================================================
# PROMPT
# ============================================================================

function prompt {
    return "$promptStyle"
}

"@
}

function Build-Secrets {
    param($config)
    
    Write-Host "`n=== Building Secrets ===" -ForegroundColor Cyan
    
    # Safe property access
    $secretsMgmt = Get-PropertyValue $config 'secrets_management' $null
    $scriptPath = if ($secretsMgmt) { Get-PropertyValue $secretsMgmt 'script_path' '' } else { '' }
    
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Secrets build script not found: $scriptPath"
        Write-Warning "Skipping secrets generation"
        return
    }
    
    try {
        & $scriptPath
        Write-Host "  [OK] Secrets generated" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to generate secrets: $_"
    }
}

# ============================================================================
# POWERSHELL PROFILE GENERATION
# ============================================================================

function Build-PowerShellProfile {
    param($config, $helpers, $configPath, $helpersPath)

    Write-Host "`n=== Generating PowerShell Profile ===" -ForegroundColor Cyan
    $profileContent = [System.Text.StringBuilder]::new()
    
    # Add header
    [void]$profileContent.Append((Generate-Header $configPath $helpersPath))
    
    # Add mode logic (param block and mode initialization function)
    [void]$profileContent.Append((Generate-ModeLogic $config))
    
    # Import environment file function
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

    # Add core functions
    [void]$profileContent.Append((Generate-InitializeDevEnvironment $config))
    [void]$profileContent.Append((Generate-ShowEnv $config))
    [void]$profileContent.Append((Generate-CheckVersions $config))
    [void]$profileContent.Append((Generate-TopicCommands $helpers))
    [void]$profileContent.Append((Generate-TopicExamples $helpers))
    [void]$profileContent.Append((Generate-Aliases $config))
    [void]$profileContent.Append((Generate-Prompt $config))
    
    # Startup sequence
    [void]$profileContent.AppendLine("`n# --- CDE Startup Sequence ---")
    [void]$profileContent.AppendLine("Clear-Host")
    [void]$profileContent.AppendLine("Initialize-DevEnvironment")
    [void]$profileContent.AppendLine("`n# Load secrets")
    # Safe property access for secrets and profile paths
    $secretsMgmt = Get-PropertyValue $config 'secrets_management' $null
    $secretsOutputFilePs = if ($secretsMgmt) { Get-PropertyValue $secretsMgmt 'output_file_ps' '' } else { '' }
    
    [void]$profileContent.AppendLine("Import-EnvFile -Path `"$secretsOutputFilePs`"")
    [void]$profileContent.AppendLine("")
    [void]$profileContent.AppendLine("# --- Mode Initialization ---")
    [void]$profileContent.AppendLine("if (`$Mode -ne 'Default') {")
    [void]$profileContent.AppendLine("    Initialize-ModeEnvironment -Mode `$Mode")
    [void]$profileContent.AppendLine("}")
    [void]$profileContent.AppendLine("`nshow-env")
    
    $profiles = Get-PropertyValue $config 'profiles' $null
    $profilesWindows = if ($profiles) { Get-PropertyValue $profiles 'windows' $null } else { $null }
    $outputPath = if ($profilesWindows) { Get-PropertyValue $profilesWindows 'ps_out' '' } else { '' }
    
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
    
    Write-Host "`n=== Synchronizing Unix Bash Profiles ===" -ForegroundColor Cyan
    
    # Safe property access
    $profiles = Get-PropertyValue $config 'profiles' $null
    $unixProfiles = if ($profiles) { Get-PropertyValue $profiles 'unix' $null } else { $null }
    $generatedProfileWinPath = if ($unixProfiles) { Get-PropertyValue $unixProfiles 'bash_out' '' } else { '' }
    
    $generatedProfileWslPath = Convert-PathForWSL $generatedProfileWinPath
    
    $bashrcFixerScript = @"
#!/bin/bash
set -e
GENERATED_PROFILE_PATH="$generatedProfileWslPath"
BASHRC_PATH="\$HOME/.bashrc"
BASH_PROFILE_PATH="\$HOME/.bash_profile"

echo "--- Synchronizing .bashrc ---"
printf '%s\n' ". \"\`$GENERATED_PROFILE_PATH\"" > "\`$BASHRC_PATH"
echo "[OK] .bashrc synchronized to source: \`$GENERATED_PROFILE_PATH"

echo "--- Creating .bash_profile ---"
cat > "\`$BASH_PROFILE_PATH" << 'PROFILE_EOF'
# Source .bashrc if it exists
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
PROFILE_EOF
echo "[OK] .bash_profile created to source .bashrc"
"@
    
    try {
        $bashrcFixerScript.Replace("`r`n", "`n") | wsl.exe -d Debian -- bash -s
        Write-Host "  [OK] .bashrc and .bash_profile synchronized" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to sync bash profiles: $_"
    }
}

function Build-UnixProfiles {
    param($config, $helpers, $UnixTemplatesPath)
    
    Write-Host "`n=== Generating Unix Profiles ===" -ForegroundColor Cyan
    
    $unixBuilderPath = Join-Path $UnixTemplatesPath "unix_builder.sh"
    if (-not (Test-Path $unixBuilderPath)) {
        throw "Unix builder template not found: $unixBuilderPath"
    }
    
    # Safe property access for secrets file
    $secretsMgmt = Get-PropertyValue $config 'secrets_management' $null
    $secretsFileNix = if ($secretsMgmt) { Get-PropertyValue $secretsMgmt 'output_file_nix' '' } else { '' }
    $secretsFileWsl = Convert-PathForWSL $secretsFileNix

    # Use safe property access for all nested configuration
    $secureEnv = Get-PropertyValue $config 'secure_env' @{}
    $profiles = Get-PropertyValue $config 'profiles' $null
    $bashOutPath = if ($profiles) { 
        $unixProfiles = Get-PropertyValue $profiles 'unix' $null
        if ($unixProfiles) {
            Convert-PathForWSL (Get-PropertyValue $unixProfiles 'bash_out' '')
        } else { '' }
    } else { '' }
    
    $zshOutPath = if ($profiles) {
        $unixProfiles = Get-PropertyValue $profiles 'unix' $null
        if ($unixProfiles) {
            Convert-PathForWSL (Get-PropertyValue $unixProfiles 'zsh_out' '')
        } else { '' }
    } else { '' }
    
    $workspace = Get-PropertyValue $config.workspace 'wsl' ''
    $envVars = Get-PropertyValue $config 'env' $null
    $envUsername = if ($envVars) { Get-PropertyValue $envVars 'USERNAME' '' } else { '' }
    $envAmpProject = if ($envVars) { Get-PropertyValue $envVars 'AMP_DEV_PROJECT' '' } else { '' }
    $envNodeOptions = if ($envVars) { Get-PropertyValue $envVars 'NODE_OPTIONS' '' } else { '' }
    
    $navigation = Get-PropertyValue $config 'navigation' $null
    $navigationWsl = if ($navigation) { Get-PropertyValue $navigation 'wsl' @{} } else { @{} }
    
    $platform = Get-PropertyValue $config 'platform' $null
    $platformWsl = if ($platform) { Get-PropertyValue $platform 'wsl' @{} } else { @{} }
    
    $ux = Get-PropertyValue $config 'ux' @{}
    $modes = Get-PropertyValue $config 'modes' @{}

    $unixPayload = [PSCustomObject]@{
        secure_env = $secureEnv
        bashOutPath = $bashOutPath
        zshOutPath = $zshOutPath
        workspace = $workspace
        secretsFile = $secretsFileWsl
        envUsername = $envUsername
        envAmpProject = $envAmpProject
        envNodeOptions = $envNodeOptions
        navigation = $navigationWsl
        helpers = $helpers
        platform = $platformWsl
        ux = $ux
        modes = $modes
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
    
    # Safe property access
    $profiles = Get-PropertyValue $config 'profiles' $null
    $unixProfiles = if ($profiles) { Get-PropertyValue $profiles 'unix' $null } else { $null }
    
    $bashFile = if ($unixProfiles) { Get-PropertyValue $unixProfiles 'bash_out' '' } else { '' }
    $zshFile = if ($unixProfiles) { Get-PropertyValue $unixProfiles 'zsh_out' '' } else { '' }
    
    $bashFileWsl = Convert-PathForWSL $bashFile
    $zshFileWsl = Convert-PathForWSL $zshFile
    
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
    Write-Host "   Profile Generator v18.0" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta
    
    Test-Prerequisites -ConfigPath $ConfigPath -HelpersPath $HelpersPath -UnixTemplatesPath $UnixTemplatesPath
    
    Write-Host "=== Loading Configuration ===" -ForegroundColor Cyan
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    $configAbsPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
        $ConfigPath
    } else {
        Join-Path $scriptRoot $ConfigPath
    }
    
    $helpersAbsPath = if ([System.IO.Path]::IsPathRooted($HelpersPath)) {
        $HelpersPath
    } else {
        Join-Path $scriptRoot $HelpersPath
    }
    
    Import-Module 'powershell-yaml'
    $rawConfig = Get-Content -Path $configAbsPath -Raw | ConvertFrom-Yaml
    $config = Resolve-ConfigVariables -Node $rawConfig -Root $rawConfig
    Write-Host "  [OK] Configuration loaded and resolved" -ForegroundColor Green
    
    $helpers = Load-HelperConfiguration -HelpersPath $helpersAbsPath
    
    Build-Secrets -config $config
    Build-PowerShellProfile -config $config -helpers $helpers -configPath $configAbsPath -helpersPath $helpersAbsPath
    Sync-UnixBashrc -config $config
    Build-UnixProfiles -config $config -helpers $helpers -UnixTemplatesPath $UnixTemplatesPath
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
