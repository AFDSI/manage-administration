# YAML Configuration Changes for Unix Header

**File to Edit:** `profile-values.yaml`

---

## 🐛 Issues to Fix in Debian Terminal Header

### Issue 1: Platform Name
**Current:** "Platform: WSL Debian/Ubuntu"  
**Should be:** "Platform: WSL Debian"

**YAML Location:**
```yaml
platform:
  wsl:
    name: "WSL Debian"  # Change from "WSL Debian/Ubuntu"
```

---

### Issue 2-3: Help Text (Split into two lines)
**Current:** 
```
Run 'check_versions' to verify tool setup or 'check_env' to refresh.
```

**Should be (two separate lines):**
```
Run 'check_versions' to verify tool setup.
Run 'check_env' to refresh.
```

**YAML Location:**
```yaml
ux:
  help_text: |
    Run 'check_versions' to verify tool setup.
    Run 'check_env' to refresh.
    Run 'show_commands <topic>' for topic-specific commands.
    Run 'show_examples <topic>' for topic-specific examples.
```

Or if it's structured differently:
```yaml
ux:
  unix_help:
    - "Run 'check_versions' to verify tool setup."
    - "Run 'check_env' to refresh."
    - "Run 'show_commands <topic>' for topic-specific commands."
    - "Run 'show_examples <topic>' for topic-specific examples."
```

---

### Issue 4-5: Home/Workspace (Show both separately)
**Current:**
```
Home/Workspace: /mnt/e/users/gigster/workspace
```

**Should be (two separate lines):**
```
Home: /mnt/e/users/gigster/workspace
Workspace: /mnt/e/users/gigster/workspace
```

**YAML Location:**
```yaml
workspace:
  wsl: "/mnt/e/users/gigster/workspace"

# And potentially also:
ux:
  show_home: true
  show_workspace: true
  # If these existed, they might control whether both are shown
```

**Note:** This might require a change to the Unix builder template (`unix_builder.sh`) if the template currently only shows one line. The template would need to be modified to show both:
```bash
echo "Home: ${WORKSPACE}"
echo "Workspace: ${WORKSPACE}"
```

---

### Issue 6: Remove AMP Project Line
**Current:**
```
AMP Project: /mnt/e/users/gigster/workspace/repos/amp.dev
```

**Should be:** (removed entirely)

**YAML Change:**

**Option 1 - Remove or comment out the AMP_DEV_PROJECT:**
```yaml
env:
  USERNAME: "gigster"
  NODE_OPTIONS: "--max-old-space-size=4096"
  # AMP_DEV_PROJECT: "/mnt/e/users/gigster/workspace/repos/amp.dev"  # Commented out
```

**Option 2 - If there's a UX flag, disable it:**
```yaml
ux:
  show_amp_project: false  # If this exists
```

**Option 3 - Template Change:**
If the template always shows AMP_DEV_PROJECT when it exists, you'll need to modify `unix_builder.sh` to not display it. Look for a line like:
```bash
[ -n "$AMP_PROJECT" ] && echo "AMP Project: $AMP_PROJECT"
```
And remove or comment it out.

---

## 🔍 Finding the Exact Keys

If you're unsure about the exact structure, share your `profile-values.yaml` file and I can pinpoint the exact keys to change.

Alternatively, you can search in your YAML file:

```bash
# Find platform text
grep -n "Debian/Ubuntu" profile-values.yaml

# Find workspace/home text
grep -n "Home/Workspace" profile-values.yaml

# Find AMP project
grep -n "AMP_DEV_PROJECT" profile-values.yaml

# Find help text
grep -n "check_env" profile-values.yaml
```

---

## 🎯 Quick Summary

1. ✏️ **Edit `profile-values.yaml`** with the changes above
2. 🔄 **Re-run the generator:**
   ```powershell
   .\profile-build.ps1 `
       -ConfigPath .\profile-values.yaml `
       -HelpersPath .\profile-helpers-en.yaml `
       -UnixTemplatesPath .\templates
   ```
3. ✅ **Test in Debian:** Open a new Debian terminal to see the updated header

---

## 📝 Note on Template vs Config

Some of these changes might be in the **template** (`templates/unix_builder.sh`) rather than the config:

- **Config changes:** Platform name, environment variables, workspace paths
- **Template changes:** Formatting, which fields to display, help text layout

If changing the YAML doesn't work for items 4-5 (Home/Workspace split), you'll need to modify the template.
