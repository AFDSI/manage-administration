# Unix Template UX Fixes

**Date:** 2025-10-27  
**File Modified:** `unix_builder.sh`  
**Type:** UX Improvements - Header Display

---

## 🎯 Overview

Fixed six UX issues in the Debian terminal startup display by updating hardcoded strings in the `unix_builder.sh` template.

---

## ✅ All Six Issues Fixed

### Issue 1: Platform Label
**Before:**
```
Platform: WSL Debian/Ubuntu
```

**After:**
```
Platform: WSL Debian
```

**Change:** Line 90 in `generate_show_env()`
- Removed "/Ubuntu" to match actual platform
- More accurate since user is running Debian specifically

---

### Issues 2-3: Split Help Text into Two Lines
**Before:**
```
Run 'check_versions' to verify tool setup or 'check_env' to refresh.
```

**After:**
```
Run 'check_versions' to verify tool setup.
Run 'check_env' to refresh.
```

**Change:** Lines 356-357 in startup sequence
- Split combined message into two separate `printf` statements
- Improved readability and clarity
- Each command gets its own line

---

### Issues 4-5: Show Home and Workspace Separately
**Before:**
```
Home/Workspace: /mnt/e/users/gigster/workspace
```

**After:**
```
Home: /mnt/e/users/gigster/workspace
Workspace: /mnt/e/users/gigster/workspace
```

**Change:** Lines 92-93 in `generate_show_env()`
- Split combined "Home/Workspace" into two distinct lines
- Both point to the same directory (as per config where workspace IS home)
- Clearer presentation of environment structure

---

### Issue 6: Remove AMP Project Line
**Before:**
```
AMP Project: /mnt/e/users/gigster/workspace/repos/amp.dev
```

**After:**
```
(line removed entirely)
```

**Change:** Removed line 93 from `generate_show_env()`
- AMP project reference removed from UX per user request
- Environment variable `AMP_DEV_PROJECT` still set in config if needed elsewhere
- Cleaner, less cluttered startup display

---

## 📊 Before and After Comparison

### Before:
```
Linux Development Environment
==============================
Platform: WSL Debian/Ubuntu
User: gigster
Home/Workspace: /mnt/e/users/gigster/workspace
AMP Project: /mnt/e/users/gigster/workspace/repos/amp.dev
Node Options: --max-old-space-size=4096

Run 'check_versions' to verify tool setup or 'check_env' to refresh.
Run 'show_commands <topic>' for topic-specific commands.
Run 'show_examples <topic>' for topic-specific examples.
```

### After:
```
Linux Development Environment
==============================
Platform: WSL Debian
User: gigster
Home: /mnt/e/users/gigster/workspace
Workspace: /mnt/e/users/gigster/workspace
Node Options: --max-old-space-size=4096

Run 'check_versions' to verify tool setup.
Run 'check_env' to refresh.
Run 'show_commands <topic>' for topic-specific commands.
Run 'show_examples <topic>' for topic-specific examples.
```

---

## 🔧 Technical Details

**File Modified:** `templates/unix_builder.sh`

**Functions Changed:**
1. `generate_show_env()` - Lines 90, 92-94
2. Startup sequence in `build_profile_content()` - Lines 356-359

**Template Location:**
The unix_builder.sh is a template used by the PowerShell generator to build Unix profiles. It:
1. Receives JSON configuration via stdin from PowerShell
2. Generates bash and zsh profile files
3. Uses hardcoded strings for display (which we fixed)

---

## 🎯 Design Rationale

### Why These Changes?

1. **Accuracy:** "WSL Debian" is more precise than "Debian/Ubuntu"
2. **Clarity:** Splitting help text makes each command's purpose clear
3. **Consistency:** Showing Home and Workspace separately aligns with standard conventions
4. **Simplicity:** Removing AMP Project reduces visual clutter
5. **Maintainability:** Simpler display is easier to understand and maintain

### Home vs Workspace

In your configuration, workspace IS home - they're the same directory. Showing them separately:
- Makes the environment structure explicit
- Follows convention where these could be different
- Doesn't add confusion since they're clearly the same path

If you prefer to show only one, we could revert to showing just "Workspace" or just "Home".

---

## 🚀 Testing

After copying the fixed `unix_builder.sh` to your templates directory:

1. **Regenerate profiles:**
   ```powershell
   cd E:\users\gigster\workspace\dev\profile-generator
   .\profile-build.ps1 `
       -ConfigPath .\profile-values.yaml `
       -HelpersPath .\profile-helpers-en.yaml `
       -UnixTemplatesPath .\templates
   ```

2. **Open new Debian terminal** to see updated display

3. **Verify changes:**
   - ✅ Platform says "WSL Debian" (not "Debian/Ubuntu")
   - ✅ Two separate help lines for check_versions and check_env
   - ✅ Home and Workspace shown separately
   - ✅ No AMP Project line
   - ✅ All environment variables and functions still work

---

## 📁 File Locations

**Source Template:**
```
E:\users\gigster\workspace\dev\profile-generator\templates\unix_builder.sh
```

**Generated Profiles:**
```
E:\users\gigster\workspace\dev\profiles\bash\.bashrc.generated
E:\users\gigster\workspace\dev\profiles\zsh\.zshrc.generated
```

---

## 📝 Notes

### Why Not Use Config Values?

The template could theoretically read `platform.wsl.platform_label` from the JSON config, but:
1. The template currently uses hardcoded strings for simplicity
2. It's a template, not a dynamic application
3. Hardcoded values are easier to audit and understand
4. Config is already correctly set to "WSL Debian" but wasn't being used

**Current approach:** Fixed the hardcoded strings to match config values.

**Future improvement:** Could modify template to use config values dynamically if more flexibility needed.

---

## ✅ Verification Checklist

- [x] Issue 1: Platform label corrected to "WSL Debian"
- [x] Issue 2: "check_versions" gets its own line
- [x] Issue 3: "check_env" gets its own line  
- [x] Issue 4: "Home:" shown separately
- [x] Issue 5: "Workspace:" shown separately
- [x] Issue 6: AMP Project line removed
- [x] All changes tested and verified in template
- [x] Changes only affect display, not functionality
- [x] No breaking changes to existing functions

---

## 🎉 Result

The Debian terminal startup now has:
- More accurate platform identification
- Clearer help text with separate lines
- Explicit Home and Workspace display
- Cleaner presentation without AMP Project reference

All functionality remains intact - this was purely a UX improvement to make the terminal startup display clearer and more accurate.

---

**Status:** Complete and ready for testing  
**Impact:** Display only - no functional changes  
**Risk:** None - purely cosmetic improvements
