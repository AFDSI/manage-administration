<#
.SYNOPSIS
    SSH Key Management System v1.0
.DESCRIPTION
    Manages SSH keys for multiple services (GitHub, WinSCP, etc.)
    Consistent architecture with secrets-build.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'add', 'remove', 'validate', 'edit', 'configure', 'test')]
    [string]$Command = 'list',
    
    [Parameter(Position = 1)]
    [string]$Name,
    
    [string]$Service,
    [string]$PrivateKeyPath,
    [string]$PublicKeyPath,
    [string]$Host,
    [string]$User,
    [string]$Dir,
    
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

class SSHConfig {
    [string]$SSHDir
    [string]$ConfigYaml
    [string]$SSHConfigFile
    [string]$KnownHostsFile
    
    SSHConfig([string]$dir) {
        if ($dir) {
            $this.SSHDir = $dir
        }
        else {
            $homeDir = [System.Environment]::GetFolderPath('UserProfile')
            $this.SSHDir = Join-Path $homeDir '.ssh'
        }
        
        $this.ConfigYaml = Join-Path $this.SSHDir 'keys.yaml'
        $this.SSHConfigFile = Join-Path $this.SSHDir 'config'
        $this.KnownHostsFile = Join-Path $this.SSHDir 'known_hosts'
    }
}

$Config = [SSHConfig]::new($Dir)

# ============================================================================
# UTILITIES
# ============================================================================

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    
    $prefix = switch ($Level) {
        'Info'    { '[INFO]' }
        'Success' { '[OK]' }
        'Warning' { '[WARN]' }
        'Error'   { '[ERROR]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Ensure-YamlModule {
    if (Get-Module -ListAvailable -Name 'powershell-yaml') {
        Import-Module powershell-yaml -ErrorAction Stop
        return
    }
    
    Write-Status "Installing powershell-yaml module..." -Level Info
    Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Force -AllowClobber
    Import-Module powershell-yaml -ErrorAction Stop
    Write-Status "Module installed successfully" -Level Success
}

function Initialize-SSHDirectory {
    # Create .ssh directory
    if (-not (Test-Path $Config.SSHDir)) {
        New-Item -ItemType Directory -Path $Config.SSHDir -Force | Out-Null
        
        # Set permissions (Unix: 700, Windows: restricted)
        if (-not $IsWindows) {
            chmod 700 $Config.SSHDir
        }
    }
    
    # Create keys.yaml if missing
    if (-not (Test-Path $Config.ConfigYaml)) {
        $defaultContent = @"
# SSH Keys Configuration
# Managed by ssh-build.ps1

keys: []

# Example entry:
# keys:
#   - name: "GitHub"
#     service: "github"
#     private_key: "~/.ssh/id_rsa_github"
#     public_key: "~/.ssh/id_rsa_github.pub"
#     host: "github.com"
#     user: "git"
"@
        Set-Content -Path $Config.ConfigYaml -Value $defaultContent -Encoding UTF8
        Write-Status "Created SSH config: $($Config.ConfigYaml)" -Level Info
    }
}

function Resolve-SSHPath {
    param([string]$Path)
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    
    # Expand ~ to home directory
    if ($Path.StartsWith('~')) {
        $homeDir = [System.Environment]::GetFolderPath('UserProfile')
        $Path = $Path -replace '^~', $homeDir
    }
    
    # Resolve relative paths
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $Path = Join-Path $Config.SSHDir $Path
    }
    
    return $Path
}

# ============================================================================
# YAML OPERATIONS
# ============================================================================

function Get-SSHKeys {
    Ensure-YamlModule
    Initialize-SSHDirectory
    
    $content = Get-Content -Path $Config.ConfigYaml -Raw -ErrorAction Stop
    $data = ConvertFrom-Yaml $content
    
    if (-not $data -or -not $data.keys) {
        return @()
    }
    
    return $data.keys
}

function Save-SSHKeys {
    param([array]$Keys)
    
    Ensure-YamlModule
    
    $data = @{ keys = $Keys }
    $yaml = ConvertTo-Yaml $data
    Set-Content -Path $Config.ConfigYaml -Value $yaml -Encoding UTF8
    
    Write-Status "Saved SSH configuration" -Level Success
}

# ============================================================================
# SSH KEY VALIDATION
# ============================================================================

function Test-SSHKey {
    param(
        [string]$PrivateKeyPath,
        [string]$PublicKeyPath
    )
    
    $issues = @()
    
    # Check private key
    $privatePath = Resolve-SSHPath $PrivateKeyPath
    if (-not (Test-Path $privatePath)) {
        $issues += "Private key not found: $privatePath"
    }
    else {
        # Check permissions (should be restrictive)
        if (-not $IsWindows) {
            $perms = (stat -c %a $privatePath 2>$null)
            if ($perms -ne '600') {
                $issues += "Private key has incorrect permissions: $perms (should be 600)"
            }
        }
    }
    
    # Check public key
    $publicPath = Resolve-SSHPath $PublicKeyPath
    if (-not (Test-Path $publicPath)) {
        $issues += "Public key not found: $publicPath"
    }
    
    return $issues
}

function Test-SSHConnection {
    param(
        [string]$Host,
        [string]$User,
        [string]$PrivateKeyPath
    )
    
    $keyPath = Resolve-SSHPath $PrivateKeyPath
    
    if (-not (Test-Path $keyPath)) {
        return @{ Success = $false; Message = "Key file not found" }
    }
    
    try {
        $result = ssh -i $keyPath -o BatchMode=yes -o ConnectTimeout=5 "$User@$Host" echo "OK" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            return @{ Success = $true; Message = "Connection successful" }
        }
        else {
            return @{ Success = $false; Message = $result }
        }
    }
    catch {
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

# ============================================================================
# COMMANDS
# ============================================================================

function Invoke-List {
    $keys = Get-SSHKeys
    
    if ($keys.Count -eq 0) {
        Write-Status "No SSH keys configured" -Level Warning
        Write-Status "Use 'add' command to register SSH keys" -Level Info
        return
    }
    
    $rows = @()
    foreach ($key in $keys) {
        $privatePath = Resolve-SSHPath $key.private_key
        $publicPath = Resolve-SSHPath $key.public_key
        
        $privateExists = Test-Path $privatePath
        $publicExists = Test-Path $publicPath
        
        $status = if ($privateExists -and $publicExists) {
            'OK'
        }
        elseif ($privateExists) {
            'PARTIAL'
        }
        else {
            'MISSING'
        }
        
        $rows += [PSCustomObject]@{
            Name = $key.name
            Service = $key.service
            Host = $key.host
            User = $key.user
            Status = $status
        }
    }
    
    $rows | Format-Table -AutoSize
    
    Write-Host ""
    Write-Status "Total: $($keys.Count) SSH keys configured" -Level Info
    Write-Status "Config: $($Config.ConfigYaml)" -Level Info
}

function Invoke-Add {
    param(
        [string]$Name,
        [string]$Service,
        [string]$PrivateKeyPath,
        [string]$PublicKeyPath,
        [string]$Host,
        [string]$User
    )
    
    # Validate required parameters
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name is required. Usage: add -Name <name> -Service <service> -PrivateKeyPath <path> ..."
    }
    
    # Check if name already exists
    $keys = Get-SSHKeys
    if ($keys | Where-Object { $_.name -eq $Name }) {
        if (-not $Force) {
            throw "SSH key '$Name' already exists. Use -Force to overwrite."
        }
        Write-Status "Overwriting existing key: $Name" -Level Warning
        $keys = @($keys | Where-Object { $_.name -ne $Name })
    }
    
    # Auto-generate public key path if not provided
    if ([string]::IsNullOrWhiteSpace($PublicKeyPath) -and -not [string]::IsNullOrWhiteSpace($PrivateKeyPath)) {
        $PublicKeyPath = "$PrivateKeyPath.pub"
    }
    
    # Validate key files exist
    $issues = Test-SSHKey -PrivateKeyPath $PrivateKeyPath -PublicKeyPath $PublicKeyPath
    if ($issues.Count -gt 0) {
        Write-Status "Key validation issues found:" -Level Warning
        foreach ($issue in $issues) {
            Write-Status "  $issue" -Level Warning
        }
        
        if (-not $Force) {
            throw "Use -Force to add keys with validation issues"
        }
    }
    
    # Create new key entry
    $newKey = @{
        name = $Name
        service = $Service
        private_key = $PrivateKeyPath
        public_key = $PublicKeyPath
        host = $Host
        user = $User
    }
    
    # Add to collection
    $keys += $newKey
    Save-SSHKeys $keys
    
    Write-Status "Added SSH key: $Name" -Level Success
}

function Invoke-Remove {
    param([string]$Name)
    
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name is required. Usage: remove <name>"
    }
    
    $keys = Get-SSHKeys
    $filtered = @($keys | Where-Object { $_.name -ne $Name })
    
    if ($filtered.Count -eq $keys.Count) {
        Write-Status "SSH key '$Name' not found" -Level Warning
        return
    }
    
    Save-SSHKeys $filtered
    Write-Status "Removed SSH key: $Name" -Level Success
}

function Invoke-Validate {
    $keys = Get-SSHKeys
    
    if ($keys.Count -eq 0) {
        Write-Status "No SSH keys configured" -Level Warning
        return
    }
    
    $totalIssues = 0
    
    foreach ($key in $keys) {
        Write-Status "Validating: $($key.name)" -Level Info
        
        $issues = Test-SSHKey -PrivateKeyPath $key.private_key -PublicKeyPath $key.public_key
        
        if ($issues.Count -eq 0) {
            Write-Status "  [OK] Key files found" -Level Success
        }
        else {
            foreach ($issue in $issues) {
                Write-Status "  [X] $issue" -Level Error
                $totalIssues++
            }
        }
    }
    
    Write-Host ""
    if ($totalIssues -eq 0) {
        Write-Status "Validation passed for all $($keys.Count) keys" -Level Success
    }
    else {
        throw "Validation failed with $totalIssues issue(s)"
    }
}

function Invoke-Configure {
    $keys = Get-SSHKeys
    
    if ($keys.Count -eq 0) {
        Write-Status "No SSH keys configured" -Level Warning
        return
    }
    
    # Generate SSH config entries
    $configLines = @("# Generated by ssh-build.ps1", "")
    
    foreach ($key in $keys) {
        if ([string]::IsNullOrWhiteSpace($key.host)) {
            continue
        }
        
        $configLines += "Host $($key.host)"
        if ($key.user) {
            $configLines += "  User $($key.user)"
        }
        $configLines += "  IdentityFile $(Resolve-SSHPath $key.private_key)"
        $configLines += "  IdentitiesOnly yes"
        $configLines += ""
    }
    
    $configContent = $configLines -join "`n"
    
    # Show preview
    Write-Host ""
    Write-Status "Generated SSH config:" -Level Info
    Write-Host $configContent
    Write-Host ""
    
    # Ask to append to ~/.ssh/config
    $confirm = Read-Host "Append to $($Config.SSHConfigFile)? (y/N)"
    if ($confirm -eq 'y') {
        Add-Content -Path $Config.SSHConfigFile -Value "`n$configContent" -Encoding UTF8
        Write-Status "Appended to SSH config" -Level Success
    }
}

function Invoke-Test {
    param([string]$Name)
    
    $keys = Get-SSHKeys
    
    if ([string]::IsNullOrWhiteSpace($Name)) {
        # Test all keys
        foreach ($key in $keys) {
            if ([string]::IsNullOrWhiteSpace($key.host) -or [string]::IsNullOrWhiteSpace($key.user)) {
                Write-Status "$($key.name): Skipped (missing host/user)" -Level Warning
                continue
            }
            
            Write-Status "Testing: $($key.name) ($($key.user)@$($key.host))" -Level Info
            $result = Test-SSHConnection -Host $key.host -User $key.user -PrivateKeyPath $key.private_key
            
            if ($result.Success) {
                Write-Status "  [OK] $($result.Message)" -Level Success
            }
            else {
                Write-Status "  [X] $($result.Message)" -Level Error
            }
        }
    }
    else {
        # Test specific key
        $key = $keys | Where-Object { $_.name -eq $Name } | Select-Object -First 1
        
        if (-not $key) {
            throw "SSH key '$Name' not found"
        }
        
        if ([string]::IsNullOrWhiteSpace($key.host) -or [string]::IsNullOrWhiteSpace($key.user)) {
            throw "Cannot test: missing host or user information"
        }
        
        Write-Status "Testing: $Name ($($key.user)@$($key.host))" -Level Info
        $result = Test-SSHConnection -Host $key.host -User $key.user -PrivateKeyPath $key.private_key
        
        if ($result.Success) {
            Write-Status "[OK] $($result.Message)" -Level Success
        }
        else {
            Write-Status "[X] $($result.Message)" -Level Error
            exit 1
        }
    }
}

function Invoke-Edit {
    Initialize-SSHDirectory
    
    $editor = $env:EDITOR
    if (-not $editor) {
        $editor = if ($IsWindows) { 'code' } else { 'vim' }
    }
    
    Write-Status "Opening in $editor..." -Level Info
    
    try {
        & $editor $Config.ConfigYaml
    }
    catch {
        Write-Status "Failed to launch editor. Open manually:" -Level Error
        Write-Host "  $($Config.ConfigYaml)"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    switch ($Command) {
        'list'      { Invoke-List }
        'add'       { Invoke-Add -Name $Name -Service $Service -PrivateKeyPath $PrivateKeyPath -PublicKeyPath $PublicKeyPath -Host $Host -User $User }
        'remove'    { Invoke-Remove -Name $Name }
        'validate'  { Invoke-Validate }
        'edit'      { Invoke-Edit }
        'configure' { Invoke-Configure }
        'test'      { Invoke-Test -Name $Name }
    }
}
catch {
    Write-Status $_.Exception.Message -Level Error
    exit 1
}