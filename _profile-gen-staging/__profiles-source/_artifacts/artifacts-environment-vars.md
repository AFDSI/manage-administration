
## artifacts - environment variables

### --- repo roots ---
```pwsh
export REPO_ROOT="/mnt/e/repos"
export AMP_DEV_ROOT="$REPO_ROOT/amp.dev.4"
```

### add common bin locations you keep on E:
```pwsh
export PATH="$REPO_ROOT/bin:$PATH"
```

### Node (if using nvm in WSL)
```pwsh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### npm caches on E: to keep C: clean (optional)
```pwsh
export NPM_CONFIG_CACHE="/mnt/e/.cache/npm"
export NPM_CONFIG_TMP="/mnt/e/.cache/npm-tmp"
mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_TMP"
```

### Python temp/builds on E: (optional)
```pwsh
export TMPDIR="/mnt/e/.cache/tmp"
mkdir -p "$TMPDIR"
```

##### WSL

- Aim to make **`/mnt/e` the single source of truth** and avoid Windows-side repo paths.

```bash
export REPO_ROOT="/mnt/e/repos"
export AMP_DEV_ROOT="$REPO_ROOT/amp.dev.4"
```

- fail-safe guards

```bash
[ -d "$REPO_ROOT" ] || mkdir -p "$REPO_ROOT"
```

- add common bin locations you keep on E:

```bash
export PATH="$REPO_ROOT/bin:$PATH"
```

- Node (if using nvm in WSL)

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

- npm caches on E: to keep C: clean

```bash
export NPM_CONFIG_CACHE="/mnt/e/.cache/npm"
export NPM_CONFIG_TMP="/mnt/e/.cache/npm-tmp"
mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_TMP"
```

- Python temp/builds on E:

```bash
export TMPDIR="/mnt/e/.cache/tmp"
mkdir -p "$TMPDIR"
```
#### Environment Variables Strategy

Add to your shell profile (`.bashrc` or `.zshrc`):

```bash
### Redirect common development logs to /mnt/e/
export NPM_CONFIG_CACHE="/mnt/e/cache/npm"
export NPM_CONFIG_LOGS_DIR="/mnt/e/logs/npm"
export NODE_ENV_LOG_DIR="/mnt/e/logs/node"

### Python logging
export PYTHONUSERBASE="/mnt/e/cache/python"
export PYTHON_LOG_DIR="/mnt/e/logs/python"

### Git configuration logs
export GIT_CONFIG_GLOBAL="/mnt/e/config/git/.gitconfig"

### Development tool logs
export BUILD_LOG_DIR="/mnt/e/logs/gulp"
export DEVELOP_LOG_DIR="/mnt/e/logs/system"
```
