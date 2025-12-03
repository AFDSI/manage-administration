
## Systematic WSL Audit Approach

You're right to be concerned. Development sprawl creates:
- ❌ Confusion (what's actually used?)
- ❌ Security issues (outdated dependencies)
- ❌ Maintenance burden (what breaks what?)
- ❌ Slow rebuilds (processing unused code)

---

## Multi-Layer Audit Strategy

### Layer 1: Package Dependencies (Easiest)

**Python packages:**
```bash
# What's installed:
pip list > ~/audit/pip-installed.txt

# What's actually imported (requires pipreqs):
pip install --user pipreqs
cd /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20
pipreqs --force --savepath ~/audit/pip-used.txt .

# Compare:
comm -23 <(sort ~/audit/pip-installed.txt) <(sort ~/audit/pip-used.txt)
# Shows: installed but not imported
```

**Node.js packages:**
```bash
# What's declared:
cd /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20
npm list --all > ~/audit/npm-declared.txt

# What's actually used (requires depcheck):
npm install -g depcheck
depcheck > ~/audit/npm-unused.txt

# Shows unused dependencies
```

---

### Layer 2: File-Level Usage Audit

**Find files never accessed:**
```bash
# Files not accessed in last 30 days:
find /mnt/e/users/gigster/workspace -type f -atime +30 > ~/audit/files-old.txt

# Files in repos but not tracked by git:
cd /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20
git ls-files --others --exclude-standard > ~/audit/git-untracked.txt

# Large files taking space:
find /mnt/e/users/gigster/workspace -type f -size +10M -exec ls -lh {} \; > ~/audit/large-files.txt
```

---

### Layer 3: Import/Require Analysis

**What's actually imported:**
```bash
# Python imports:
grep -r "^import\|^from.*import" /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20 \
  --include="*.py" | sed 's/:.*import /\t/' | sort | uniq > ~/audit/python-imports.txt

# Node requires/imports:
grep -r "require(\|from.*import" /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20 \
  --include="*.js" --include="*.ts" | sed 's/:.*require/\trequire/' | sort | uniq > ~/audit/node-imports.txt
```

---

### Layer 4: Dead Code Detection Tools

**Python:**
```bash
# Install vulture (finds unused code):
pip install --user vulture

# Scan for unused code:
cd /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20
vulture . > ~/audit/python-deadcode.txt
```

**JavaScript:**
```bash
# Install unused-webpack-plugin or use eslint:
npm install -g eslint
cd /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20
eslint . --no-eslintrc --rule 'no-unused-vars: error' > ~/audit/js-unused.txt 2>&1
```

---

## Complete Audit Script

Create this as a reusable tool:

```bash
#!/bin/bash
# audit-workspace.sh - Comprehensive WSL workspace audit

AUDIT_DIR="$HOME/workspace-audit-$(date +%Y%m%d)"
mkdir -p "$AUDIT_DIR"

echo "Starting workspace audit..."
echo "Output directory: $AUDIT_DIR"

# 1. System packages
echo "Auditing system packages..."
dpkg -l > "$AUDIT_DIR/system-packages.txt"
apt list --installed > "$AUDIT_DIR/apt-installed.txt"

# 2. Python environment
echo "Auditing Python..."
pip list > "$AUDIT_DIR/pip-list.txt"
pip list --outdated > "$AUDIT_DIR/pip-outdated.txt"

# 3. Node.js environment
echo "Auditing Node.js..."
npm list -g --depth=0 > "$AUDIT_DIR/npm-global.txt"

# 4. Workspace structure
echo "Scanning workspace..."
du -sh /mnt/e/users/gigster/workspace/* > "$AUDIT_DIR/workspace-sizes.txt"
find /mnt/e/users/gigster/workspace -name "node_modules" -type d > "$AUDIT_DIR/node_modules-dirs.txt"
find /mnt/e/users/gigster/workspace -name "__pycache__" -type d > "$AUDIT_DIR/pycache-dirs.txt"
find /mnt/e/users/gigster/workspace -name ".git" -type d > "$AUDIT_DIR/git-repos.txt"

# 5. Large files
echo "Finding large files..."
find /mnt/e/users/gigster/workspace -type f -size +10M -exec ls -lh {} \; > "$AUDIT_DIR/large-files.txt"

# 6. Old files (not accessed in 60 days)
echo "Finding stale files..."
find /mnt/e/users/gigster/workspace -type f -atime +60 > "$AUDIT_DIR/stale-files.txt"

# 7. Git status across repos
echo "Checking git repos..."
for repo in $(find /mnt/e/users/gigster/workspace/repos -name ".git" -type d | sed 's/\.git$//'); do
    echo "=== $repo ===" >> "$AUDIT_DIR/git-status.txt"
    cd "$repo"
    git status --short >> "$AUDIT_DIR/git-status.txt"
    echo "" >> "$AUDIT_DIR/git-status.txt"
done

echo "Audit complete: $AUDIT_DIR"
ls -la "$AUDIT_DIR"
```

**Usage:**
```bash
chmod +x audit-workspace.sh
./audit-workspace.sh
```

---

## For abc.dev: Build This Into the System

**Makefile target:**
```makefile
.PHONY: audit
audit:
	@echo "Running workspace audit..."
	@./scripts/audit-workspace.sh
	@echo "Review: ~/workspace-audit-$(date +%Y%m%d)/"

.PHONY: clean-dead-code
clean-dead-code:
	@echo "WARNING: This will remove unused dependencies!"
	@read -p "Continue? [y/N] " -n 1 -r
	@echo
	@if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		npm prune; \
		pip-autoremove -y $(pip list --format=freeze | grep -v -f <(pipreqs --print .)); \
	fi
```

---

## Analysis Tools

**After audit, analyze:**

```bash
# Size breakdown:
cd ~/workspace-audit-*
cat workspace-sizes.txt | sort -h

# How many node_modules?
wc -l node_modules-dirs.txt

# Total space wasted:
du -sh $(cat node_modules-dirs.txt) | awk '{sum+=$1} END {print sum}'

# Outdated Python packages:
cat pip-outdated.txt | wc -l
```

---

## Systematic Cleanup Process

**Phase 1: Safe Cleanup (No Code Impact)**
```bash
# Remove build artifacts:
find . -name "build" -type d -exec rm -rf {} +
find . -name ".grow-cache" -type d -exec rm -rf {} +
find . -name "__pycache__" -type d -exec rm -rf {} +
find . -name "node_modules/.cache" -type d -exec rm -rf {} +

# Remove old logs:
find . -name "*.log" -type f -mtime +30 -delete
```

**Phase 2: Dependency Cleanup (Requires Testing)**
```bash
# Remove unused npm packages:
npm prune

# Update outdated packages:
npm outdated  # Review first
npm update    # Then update

# Remove unused Python packages (careful!):
pip install pip-autoremove
pip-autoremove <package>  # One at a time, test each
```

**Phase 3: Code Cleanup (Requires Verification)**
```bash
# Use vulture/eslint findings
# Manually review each before deleting
```

---

## Advanced: Dependency Graph Visualization

**For deep analysis:**

```bash
# Python dependency graph:
pip install pipdeptree
pipdeptree --graph-output png > ~/deps-python.png

# Node.js dependency graph:
npm install -g madge
madge --image ~/deps-node.png /path/to/project

# View in browser or image viewer
```

---

## Contractor Audit Checklist

**Create this for abc.dev:**

```markdown
# Workspace Audit Checklist

## Before Starting Development
- [ ] Run workspace audit script
- [ ] Review large files (>10MB)
- [ ] Check for multiple node_modules
- [ ] Verify Python environment clean

## Weekly Maintenance
- [ ] Remove build artifacts
- [ ] Check for outdated packages
- [ ] Review git status across repos
- [ ] Clean old logs

## Before Major Changes
- [ ] Full dependency audit
- [ ] Document what's actually used
- [ ] Remove confirmed dead code
- [ ] Test after cleanup
```

---

## For Your Immediate Concern

**Quick audit of amp.dev.20:**

```bash
cd /mnt/e/users/gigster/workspace/repos/amp/amp.dev.20

# What's taking space:
du -sh * | sort -h

# Node.js unused dependencies:
npx depcheck

# Python unused packages:
pipreqs --print . > ~/used.txt
pip list | diff - ~/used.txt

# Untracked files:
git status --porcelain | grep "^??" | wc -l
```

---

## Philosophy for abc.dev

**Design principle:**
```
"Only include what's explicitly needed"
```

**Implementation:**
1. ✅ Start with minimal dependencies
2. ✅ Add only when required
3. ✅ Document why each dependency exists
4. ✅ Regular audits (automated)
5. ✅ Remove promptly when no longer needed

**Makefile enforces this:**
```makefile
# Explicit dependencies only
install: validate-deps
	npm ci  # Not npm install (uses lockfile)
	pip install -r requirements.txt  # Pinned versions

validate-deps:
	@echo "Checking for unused dependencies..."
	@npx depcheck || exit 1
```

---

## Recommendation

**For now:**
1. Let grow build finish
2. Test clean startup
3. **Then** run comprehensive audit
4. Document findings for abc.dev planning

**For abc.dev:**
- Build audit into CI/CD
- Regular automated cleanup
- Dependency justification required (in ADR)
- Zero tolerance for cruft

