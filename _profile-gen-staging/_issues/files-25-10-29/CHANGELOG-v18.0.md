# Profile Generator v18.0 - Changelog & Testing Guide

**Generated:** 2025-10-27
**Version:** 18.0 - UX Standardization & Platform Detection

---

## ✅ What's New in v18.0

### 1. **Platform Detection**
- Added platform-specific configuration blocks in `profile-values.yaml`
- Standardized headers, separators, and platform labels for Windows/WSL/MacOS
- Platform-specific home directory resolution

### 2. **Mode-Specific API Status Display**
- Only shows API key status for modes with `show_api_status: true`
- Displays key status in green ([OK]) or red ([MISSING])
- Supports multiple keys per mode (e.g., AWS shows both keys)

### 3. **UX Standardization (per ux-v3.csv)**
- Consistent startup messages across all terminals
- Platform-specific headers and separators
- Standardized hints with proper function naming conventions

### 4. **Function Naming Conventions**
- **PowerShell:** Uses hyphens (`check-env`, `show-commands`)
- **Unix (Bash/Zsh):** Uses underscores (`check_env`, `show_commands`)
- Applied consistently across generated profiles

### 5. **New Modes Added**
- **Claude Code** mode with version checking
- **Google Cloud** mode with multiple API key validation

---

## 📦 Updated Files

### profile-build.ps1 (v18.0)
**Key Changes:**
```powershell
# New Functions:
- Generate-ModeLogic()         # Creates param block and mode switch
- Generate-ShowEnv()           # Platform-aware environment display
- Enhanced Generate-CheckVersions() # Added Claude Code version check

# Updated Functions:
- Generate-InitializeDevEnvironment() # Uses ux.startup.init_message
- Generate-TopicCommands()    # Proper hyphen naming
- Generate-TopicExamples()    # Proper hyphen naming
- Generate-Aliases()          # Maps hyphens to function names
```

**New Sections Generated:**
1. Mode selection parameter block
2. Initialize-ModeEnvironment function with mode-specific displays
3. API status checks per mode
4. Platform-specific headers from config

### profile-helpers-en.yaml (v18.0)
**Additions:**
```yaml
helpers:
  claude_code:
    bash:
      - Basic Operations (claude, version, help)
      - Project Management (init, status)
  
  google_cloud:
    bash:
      - Search APIs (Programmable Search)
      - Knowledge Graph
      - Maps API

examples:
  claude_code: # Interactive session examples
  google_cloud: # curl examples for each API
```

### profile-values.yaml (v18.0 - Already Updated)
**Key Sections:**
```yaml
platform:
  windows:   # Headers, separators, platform_label, home
  wsl:       # Headers, separators, platform_label, home
  macos:     # Headers, separators, platform_labels (pwsh/zsh), home

modes:
  claude_code:
    enabled: true
    show_api_status: true
    version_check: { command, name }
  
  google_cloud:
    enabled: true
    show_api_status: true
    required_secrets: [4 keys]

ux:
  startup:
    init_message: "Initializing portable development environment..."
    ready_message: "Environment is ready."
  
  hints:
    powershell: [4 hints with hyphens]
    unix: [4 hints with underscores]

conventions:
  function_naming:
    powershell: "hyphen"
    unix: "underscore"
```

---

## 🧪 Testing Checklist

### Phase 1: Generation Test
```powershell
# From Windows PowerShell
cd E:\users\gigster\workspace\dev\profile-generator
.\profile-build.ps1 `
    -ConfigPath .\profile-values.yaml `
    -HelpersPath .\profile-helpers-en.yaml `
    -UnixTemplatesPath .\templates
```

**Expected Output:**
```
========================================
   Profile Generator v18.0
========================================

=== Validating Prerequisites ===
  [OK] Config file found
  [OK] Helper file found
  [OK] Templates directory found
  [OK] All template files found
  [OK] PowerShell YAML module available
  [OK] WSL Debian is accessible

=== Loading Configuration ===
  [OK] Configuration loaded and resolved
=== Loading Helper Configuration ===
  [OK] Helpers loaded

=== Building Secrets ===
  [OK] Secrets generated

=== Generating PowerShell Profile ===
  [OK] PowerShell profile written to: ...

=== Synchronizing Unix .bashrc ===
  [OK] .bashrc synchronized

=== Generating Unix Profiles ===
  [OK] Unix profiles generated

=== Hardening Unix Profiles ===
  [OK] Unix profiles cleaned with dos2unix

========================================
   Profile Generation Complete!
========================================
```

### Phase 2: PowerShell Profile Tests

#### Test 1: Default Mode (pwsh)
```powershell
# Start new PowerShell window (no parameters)
pwsh -NoProfile -File Microsoft.PowerShell_profile.ps1
```

**Expected Output:**
```
Initializing portable development environment...
Environment is ready.

[PWSH] Environment initialized

Windows Development Environment
===============================
Platform: PowerShell 7 (cross-platform)
User: gigster
Home: C:\Users\Owner
Workspace: E:\users\gigster\workspace
Node Options: --max-old-space-size=4096

Run 'check-env' to refresh.
Run 'check-versions' to verify tool setup.
Run 'show-commands <topic>' for topic-specific commands.
Run 'show-examples <topic>' for topic-specific examples.
```

#### Test 2: AWS Mode
```powershell
pwsh -NoProfile -File Microsoft.PowerShell_profile.ps1 -Mode aws
```

**Expected Output:**
```
Initializing portable development environment...
Environment is ready.

[AWS] Environment initialized
  [OK] AWS_ACCESS_KEY_ID loaded
  [OK] AWS_SECRET_ACCESS_KEY loaded

Windows Development Environment
===============================
[...rest same as default...]
```

#### Test 3: Claude Code Mode
```powershell
pwsh -NoProfile -File Microsoft.PowerShell_profile.ps1 -Mode claude_code
```

**Expected Output:**
```
Initializing portable development environment...
Environment is ready.

[Claude Code] Environment initialized
  [OK] ANTHROPIC_API_KEY loaded

Windows Development Environment
===============================
[...rest same as default...]
```

#### Test 4: Google Cloud Mode
```powershell
pwsh -NoProfile -File Microsoft.PowerShell_profile.ps1 -Mode google_cloud
```

**Expected Output:**
```
Initializing portable development environment...
Environment is ready.

[Google Cloud] Environment initialized
  [OK] GOOGLE_PROGRAMMABLE_SEARCH_API_KEY loaded
  [OK] GOOGLE_PROGRAMMABLE_SEARCH_CSE_ID loaded
  [OK] GOOGLE_KNOWLEDGE_GRAPH_API_KEY loaded
  [OK] GOOGLE_MAPS_API_KEY loaded

Windows Development Environment
===============================
[...rest same as default...]
```

### Phase 3: Function Tests

#### Test 5: check-env (hyphenated)
```powershell
check-env
```
**Expected:** Re-displays environment info (same as startup)

#### Test 6: check-versions
```powershell
check-versions
```
**Expected:**
```
=== Tool Versions ===

Node.js: v22.21.0
Python: 3.13.0
UV: 0.x.x
Git: 2.x.x
Claude Code: 0.x.x
```

#### Test 7: show-commands
```powershell
show-commands aws
show-commands node
show-commands python
show-commands git
```
**Expected:** Displays formatted command lists per topic

#### Test 8: show-examples
```powershell
show-examples aws
show-examples git
```
**Expected:** Displays formatted example snippets per topic

### Phase 4: WSL/Bash Tests

#### Test 9: WSL Linux Mode
```bash
wsl -d Debian
# Should auto-source ~/.bashrc which sources generated profile
```

**Expected Output:**
```
Initializing portable development environment...
Environment is ready.

[LINUX] Environment initialized

Linux Development Environment
=============================
Platform: WSL Debian
User: gigster
Home: /mnt/e/users/gigster/workspace
Workspace: /mnt/e/users/gigster/workspace
Node Options: --max-old-space-size=4096

Run 'check_env' to refresh.
Run 'check_versions' to verify tool setup.
Run 'show_commands <topic>' for topic-specific commands.
Run 'show_examples <topic>' for topic-specific examples.
```

#### Test 10: Unix Function Naming (underscores)
```bash
check_env          # Should work
show_commands aws  # Should work
show_examples git  # Should work

# These should NOT work:
check-env          # Command not found
show-commands      # Command not found
```

### Phase 5: Validation Against ux-v3.csv

**Verify each column matches specification:**
- [ ] Row 2: Init message correct
- [ ] Row 3: Ready message correct
- [ ] Row 4: Mode identifier correct per mode
- [ ] Row 5-8: API status matches (only for applicable modes)
- [ ] Row 10-11: Platform header/separator correct
- [ ] Row 12: Platform label correct
- [ ] Row 13: User correct
- [ ] Row 14: Home path correct per platform
- [ ] Row 15: Workspace correct per platform
- [ ] Row 16: Node options correct
- [ ] Row 18-21: Hints correct with proper naming convention

---

## 🐛 Known Issues / Limitations

1. **MacOS Support:** Not yet tested (no MacOS environment available)
2. **Mode Parameter:** Currently only works in PowerShell; Unix profiles need mode handling implementation
3. **Version Checks:** Claude Code check assumes `claude --version` works
4. **API Key Validation:** Only checks if env var exists, not if key is valid

---

## 📋 Deployment Checklist

Before deploying to production:
- [ ] All Phase 1-5 tests pass
- [ ] Secrets are properly generated
- [ ] Both PowerShell and WSL profiles work
- [ ] All modes display correctly
- [ ] Function naming conventions work in both shells
- [ ] Version checks return expected results
- [ ] Helper commands work for all topics
- [ ] UX matches ux-v3.csv specification

---

## 🔄 Rollback Plan

If issues occur:
1. Revert to v17.0 files (backed up in git)
2. Regenerate profiles with v17.0
3. Restart terminals

**Backup Location:**
```
git log --oneline
git checkout <v17.0-commit-hash> -- profile-build.ps1 profile-helpers-en.yaml
```

---

## 📞 Support

For issues or questions about v18.0:
- Review this testing guide
- Check generated profile syntax
- Verify YAML configuration structure
- Ensure all prerequisites are met

**Version:** 18.0
**Last Updated:** 2025-10-27
