
## 🏠 **HOME Directory Mappings - Now Clear**

```
Windows:
  HOME = C:\Users\Owner
  Also accessible as: E:\users\gigster (same location, different drive letter)

WSL/Debian:
  HOME = /mnt/e/users/gigster/workspace
  (which is E:\users\gigster\workspace)

MacOS (future):
  HOME = /Users/gigster
```

---

## 📊 **Structure Analysis**

### **E:\users\gigster\ (Windows HOME / System Level)**

```
E:\users\gigster\                    ← C:\Users\Owner (Windows HOME)
    .secrets\                         ✅ System secrets (shared Windows/WSL)
    .ssh\                             ✅ System SSH keys (shared Windows/WSL)
    .env.secrets.nix                  ✅ Generated for WSL
    .env.secrets.ps1                  ✅ Generated for Windows
    
    .nvm\                             ⚠️  QUESTION: Is this Windows nvm?
    .uv\                              ⚠️  QUESTION: Is this Windows uv?
    .bashrc                           ❌ Duplicate (WSL doesn't use this)
    .bashrc.generated                 ❌ Duplicate (shouldn't be here)
    .bash_history                     ❌ Old history (WSL uses workspace one)
    .profile                          ⚠️  Maybe for WSL fallback?
    .zshrc                            ❌ You use bash, not zsh
    .cache, .config, .local, .vscode  ⚠️  May be legitimate system-level
```

### **E:\users\gigster\workspace\ (WSL HOME / Development)**

```
E:\users\gigster\workspace\          ← WSL HOME
    .nvm\                             ✅ WSL/Linux nvm (correct!)
    .pyenv\                           ✅ WSL/Linux Python
    .uv\                              ✅ WSL/Linux uv
    .bashrc                           ✅ WSL bash config (active)
    .bash_history                     ✅ WSL history (active)
    .claude\                          ✅ Claude Code settings
    .claude.json                      ✅ Claude Code config
    
    dev\                              ✅ Development tools
    repos\                            ✅ Code repositories  
    project\                          ✅ Project files
```

---

## 🔍 **Key Questions to Resolve**

### **Question 1: nvm at Parent Level**

```bash
# Check what's in parent .nvm
ls -la /mnt/e/users/gigster/.nvm/

# Is it Windows nvm? Or old WSL nvm?
# Check for Windows executables
ls -la /mnt/e/users/gigster/.nvm/*.exe 2>/dev/null

diff /mnt/e/users/gigster/.nvm/ /mnt/e/users/gigster/workspace/.nvm/

```

**Options:**
- **If Windows nvm:** Keep it (for Windows PowerShell Node.js)
- **If old WSL nvm:** Delete it (use workspace one)

### **Question 2: uv at Parent Level**

```bash
# Check what's in parent .uv
ls -la /mnt/e/users/gigster/.uv/

# Compare to workspace .uv
ls -la /mnt/e/users/gigster/workspace/.uv/
```

**Options:**
- **If Windows uv:** Keep it (for Windows Python)
- **If duplicate:** Delete parent, keep workspace

---

## 🧹 **Recommended Cleanup**

### **SAFE TO DELETE (Confirmed Duplicates):**

```bash
# These are definitely not needed at parent level
rm /mnt/e/users/gigster/.bashrc              # WSL uses workspace/.bashrc
rm /mnt/e/users/gigster/.bashrc.generated    # Profile gen is in workspace
rm /mnt/e/users/gigster/.bash_history        # WSL uses workspace history
rm /mnt/e/users/gigster/.zshrc               # You use bash
rm /mnt/e/users/gigster/.profile             # Not needed with .bashrc
```

### **INVESTIGATE BEFORE DELETING:**

```bash
# Check if these are Windows tools or duplicates
ls -la /mnt/e/users/gigster/.nvm/
ls -la /mnt/e/users/gigster/.uv/

# If duplicates (no Windows .exe files), delete:
# rm -rf /mnt/e/users/gigster/.nvm
# rm -rf /mnt/e/users/gigster/.uv
```

### **KEEP (System-level, Shared):**

```bash
# These belong at system level
E:\users\gigster\.secrets\           ✅ Shared secrets
E:\users\gigster\.ssh\               ✅ Shared SSH keys
E:\users\gigster\.env.secrets.nix    ✅ Generated for WSL
E:\users\gigster\.env.secrets.ps1    ✅ Generated for Windows
E:\users\gigster\.cache\             ✅ System cache
E:\users\gigster\.config\            ✅ System config
E:\users\gigster\.local\             ✅ System local
E:\users\gigster\.vscode\            ✅ VS Code settings
```

---

## ✅ **Profile-values.yaml Alignment**

Your `profile-values.yaml` should have:

```yaml
workspace:
  win: E:\users\gigster\workspace
  nix: /mnt/e/users/gigster/workspace

secrets:
  path_win: E:\users\gigster\.secrets
  path_nix: /mnt/e/users/gigster/.secrets
```

This means:
- **WSL HOME:** `/mnt/e/users/gigster/workspace` ✅
- **Secrets:** System-level at parent ✅
- **Development:** All in workspace ✅

---

## 🎯 **Final Recommended Structure**

```
E:\users\gigster\                         ← System (Windows HOME)
    .secrets\                              ✅ System secrets
    .ssh\                                  ✅ System SSH
    .cache\, .config\, .local\, .vscode\   ✅ System directories
    .env.secrets.nix                       ✅ Generated
    .env.secrets.ps1                       ✅ Generated
    
    workspace\                             ← WSL HOME
        .bashrc                             ✅ WSL bash config (sourced)
        .nvm\                               ✅ WSL nvm
        .pyenv\                             ✅ WSL Python
        .uv\                                ✅ WSL uv
        .claude\                            ✅ Claude settings
        
        dev\                                ✅ Tools
            bin\
            tools\
            profiles\
                bash\
                    .bashrc.generated       ✅ Generated profile
                ps\
                    profile.generated.ps1   ✅ Generated profile
        
        repos\                              ✅ Code
        project\                            ✅ Projects
```

---

## 🧪 **Diagnostic Commands**

```bash
# Run these to check before cleanup:

# 1. Check parent .nvm
ls -la /mnt/e/users/gigster/.nvm/ | head -20
file /mnt/e/users/gigster/.nvm/* | head -5

# 2. Check workspace .nvm
ls -la /mnt/e/users/gigster/workspace/.nvm/ | head -20

# 3. Check what WSL uses
echo $HOME
which nvm
which node

# 4. Check .bashrc locations
ls -l /mnt/e/users/gigster/.bashrc
ls -l /mnt/e/users/gigster/workspace/.bashrc
```

---

**Run those diagnostic commands and show me the output!** Then I'll give you exact cleanup commands based on what we find. 🔍

The key is determining if parent-level `.nvm` and `.uv` are Windows installations (keep) or duplicates (delete).