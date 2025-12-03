## discover-resources.ps1 — effectiveness & tiny upgrades

### 🔧 Suggested deltas

1. **Detect python-bin on PATH** (so we know the generator applied YAML correctly):

```powershell
$PY_BIN = Join-Path $DEV_HOME ("dev{0}tools{0}python-bin" -f [IO.Path]::DirectorySeparatorChar)
$hasPyBin = ($pathItems -contains $PY_BIN)
```

Include `hasPyBin` in the report and, if false while uv is present, flag it under a `warnings` array.

2. **Treat Python “present” if launchers exist (even if `where python` is empty)**
   In the Python section, also check:

```powershell
$pyLauncher = Join-Path $PY_BIN "python.exe"
$pythonPresent = (Test-Path $pyLauncher) -or [bool](Which "python")
```

Use `$pythonPresent` for the final `present` field.

3. **PATH order validation**
   Optionally add a check that the **first four** entries match exactly:

* `…\dev\tools\python-bin`
* `…\dev\tools\nodejs`
* `…\dev\bin`
* `…\dev\tools`

If not, emit a structured `path_order.status = "mismatch"` with the observed vs expected lists.

4. **Add `profile_values_hash`** (handy for provenance)
   If your run pipeline has the YAML path, include a SHA256 of that file.

