# PowerShell Profile Diagnostics - v18.0.7

**Date:** 2025-10-27  
**Issues:** Aliases not working, Prompt showing location

---

## ✅ Fixed: Prompt Issue

**Problem:** Prompt was showing `C:\Users\Owner$ ` instead of just `$ `

**Solution:** Removed the location display from the prompt function.

**Before:**
```powershell
function prompt {
    $location = Get-Location
    Write-Host "$location" -NoNewline -ForegroundColor Cyan
    return "$ "
}
```

**After:**
```powershell
function prompt {
    return "$ "
}
```

---

## 🔍 Investigating: Aliases Not Working

The generator DOES create these aliases (lines 665-668):

```powershell
Set-Alias -Name check-env -Value Show-Env
Set-Alias -Name check-versions -Value Check-Versions
Set-Alias -Name show-commands -Value Show-Commands
Set-Alias -Name show-examples -Value Show-Examples
```

**Since you're seeing the hints but the aliases don't work, let's diagnose:**

### Diagnostic Steps:

1. **Check if the generated profile has the aliases:**
   ```powershell
   # Open the generated profile in an editor
   code E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1
   
   # Or search for the aliases section
   Select-String -Path E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1 -Pattern "Set-Alias"
   ```

2. **Check if there are any errors when loading the profile:**
   ```powershell
   # Manually run the profile and watch for errors
   . E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1
   ```

3. **Check if the functions exist:**
   ```powershell
   # After sourcing the profile, check if the PascalCase functions exist
   Get-Command Check-Versions
   Get-Command Show-Commands
   Get-Command Show-Examples
   ```

4. **Check if the aliases exist:**
   ```powershell
   Get-Alias check-versions
   Get-Alias show-commands
   Get-Alias show-examples
   ```

---

## 🐛 Possible Causes

### Cause 1: Aliases section not in generated file
If `Select-String` shows no aliases, the generator might have an error preventing that section from being added.

### Cause 2: PowerShell execution policy
Aliases might be set but PowerShell's execution policy could be blocking them.

### Cause 3: Error before aliases are defined
If there's a PowerShell syntax error earlier in the file, the profile might stop loading before reaching the aliases.

### Cause 4: Scope issue
The aliases might be defined in a different scope than where you're trying to use them.

---

## 🔧 Quick Test

Try calling the functions directly with their PascalCase names:

```powershell
Check-Versions
Show-Commands aws
Show-Examples git
```

If these work, then the functions exist but the aliases aren't being set.
If these DON'T work, then the functions themselves aren't being generated.

---

## 📋 What to Report Back

Please share:

1. **Do the PascalCase commands work?**
   - `Check-Versions` (yes/no)
   - `Show-Commands aws` (yes/no)

2. **Do the aliases show up in the file?**
   ```powershell
   Select-String -Path E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1 -Pattern "Set-Alias"
   ```

3. **Any errors when manually sourcing?**
   ```powershell
   . E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1
   ```

4. **Check alias listing:**
   ```powershell
   Get-Alias | Where-Object { $_.Name -like "*check*" -or $_.Name -like "*show*" }
   ```

---

## 🎯 Next Steps

Once you provide the diagnostic results, we can:
- Fix any generation issues
- Adjust the alias approach if needed
- Ensure proper scope for aliases

---

## 📦 Updated Generator

The fixed generator (v18.0.7) with the prompt fix is ready in outputs.

**To apply:**
1. Copy `profile-build.ps1` v18.0.7 to your generator directory
2. Regenerate the profile
3. Run diagnostics above
4. Report back what you find
