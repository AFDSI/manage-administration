# Environment Plan

## Findings

## PATH
* Missing (to prepend, process-scoped):
  - *(none)*

## Env Vars
* Create:
  - `NVM_HOME` = `${toolchains.node.windows.nvm_home}`
  - `GROW_ENV` = `local`
  - `NVM_SYMLINK` = `${toolchains.node.windows.nvm_symlink}`
  - `NODE_OPTIONS` = `--max-old-space-size=4096`
  - `UV_PYTHON_BIN_DIR` = `${toolchains.python.windows.shim_dir}`
  - `UV_CACHE_DIR` = `${dev_home.win}\uv_cache`
  - `platform_overrides` = `System.Collections.Hashtable`
  - `AMP_DEV_PROJECT` = `${dev_home.wsl}/dev/repos/amp.dev`
  - `USERNAME` = `${identity.owner_id}`
* Update:
  - *(none)*
* Keep:
  - *(none)*

## Node/npm
* Node found: False
* npm found: False
* npm prefix: `` (on PATH: False)

## Recommendations
* Install Node or add its directory to PATH (User).
