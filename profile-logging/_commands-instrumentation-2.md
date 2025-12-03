awesome idea. here’s a tight “Instrumentation Catalogue” you can paste into your doc. each item is a lightweight probe or debug step with a clear intent and a ready-to-copy snippet.

### Instrumentation Catalogue (amp.dev local-dev)

#### 0) Environment sanity (one-liners)

**Check versions**

```bash
python --version         ### expect 3.9.x
grow --version           ### expect 2.2.3
node -v && npm -v
```

**Confirm pyenv & PATH are live**

```bash
type -a python | nl -ba
echo "$PYTHONPATH"
```

---

#### 1) YAML integrity checks (podspec & blueprints)

**Show first lines with numbers**

```bash
nl -ba podspec.yaml | sed -n '1,60p'
```

**Detect tabs & BOM**

```bash
grep -nP '\t' podspec.yaml || echo "No tabs"
xxd -l 3 -p podspec.yaml 2>/dev/null | grep -qi '^efbbbf' && echo "BOM present" || echo "No BOM"
```

**Shape probe (dict vs list)**

```bash
python - <<'PY'
import yaml, sys
data = yaml.safe_load(open('podspec.yaml','rb'))
print(type(data).__name__)
PY
```

---

#### 2) Python import probes (Grow extensions)

**Verify package markers exist**

```bash
touch pages/__init__.py pages/extensions/__init__.py pages/extensions/amp_dev/__init__.py
```

**Probe export & class location**

```bash
python - <<'PY'
import os, sys, importlib, inspect
sys.path.insert(0, os.getcwd()+"/pages")
mod = importlib.import_module("extensions.amp_dev")
print("Imported:", mod.__file__)
names = [n for n in dir(mod) if n.endswith("Extension")]
print("Exported *Extension:", names)
for n in names:
    obj = getattr(mod, n)
    print(n, "class?", inspect.isclass(obj), "from", inspect.getsourcefile(obj))
PY
```

**New-style vs legacy type (MRO)**

```bash
python - <<'PY'
import os, sys, inspect
sys.path.insert(0, os.getcwd()+"/pages")
from extensions.amp_dev.extension import AmpDevExtension
print([c.__name__ for c in inspect.getmro(AmpDevExtension)])
PY
```

> Contains `BaseExtension` → register under `ext:`.
> Contains `Preprocessor` → register under `extensions: preprocessors:`.

---

#### 3) Alias shim for Grow import (only if needed)

**Create re-export alias at repo root**

```bash
mkdir -p extensions/amp_dev
cat > extensions/amp_dev/__init__.py <<'PY'
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if ROOT not in sys.path: sys.path.insert(0, ROOT)
from pages.extensions.amp_dev.extension import AmpDevExtension  ### noqa: F401
PY
```

---

#### 4) Podspec & deployments checks

**Confirm locales + home**

* `home: /content/amp-dev/index.md`
* `localization: { default_locale: en, locales: [en], root_path: /{locale}/ }`

**Check deployment keys Grow expects**

```yaml
deployments:
  local:
    destination: local
    out_dir: dist/pages
```

---

#### 5) Minimal content path activation

**Create/verify collection blueprint**

```bash
mkdir -p content/amp-dev
cat > content/amp-dev/_blueprint.yaml <<'YAML'
path: /{locale}/amp-dev/{slug}.html
YAML
```

**Minimal doc + view + sitemap stub**

```bash
mkdir -p views layouts content/amp-dev
cat > views/base.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>{{ doc.title or 'Home' }}</title>{{ doc.body|safe }}
HTML
cat > content/amp-dev/index.md <<'MD'
---
$title: Home
$view: /views/base.html
$path: /{locale}/amp-dev/index.html
---
Hello from amp.dev — sanity page.
MD
cat > layouts/sitemap.xml <<'XML'
<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>
XML
```

---

#### 6) Grow build/debug loops

**Clean caches**

```bash
rm -rf dist/pages .cache
find . -type d -name '__pycache__' -exec rm -rf {} +
```

**Build (pod root at repo or at ./pages depending on setup)**

```bash
grow build . --out_dir=dist/pages
### or if podspec is inside pages/:
grow build pages --out_dir=dist/pages
```

**Deploy (renders full pod via deployment)**

```bash
grow deploy local
### or (if generated podspec defines 'default'):
grow deploy default pages
```

**List output**

```bash
find dist/pages -maxdepth 3 -type f | sort
```

**Common error fingerprints**

* `AttributeError: 'list' object has no attribute 'get'` → YAML top-level is a list (indentation/stray `-`).
* `ImportError: Unable to find extension module for 'extensions.…'` → wrong module path or new-style vs legacy mismatch.
* `ValueError: No pod-specific deployments configured.` → missing `deployments:` block or wrong deployment name.
* Missing template path → create stub (e.g., `/layouts/sitemap.xml`).

---

#### 7) Router/runtime checks (platform)

**Start platform w/ dist fallback**

```bash
USE_DIST_FALLBACK=1 NODE_ENV=local node platform/serve.js
```

**Health & key URLs**

```bash
curl -sI http://127.0.0.1:8080/__health-check | head -1
curl -sI http://127.0.0.1:8080/en/amp-dev/index.html | head -1
curl -sI http://127.0.0.1:8080/en/amp-dev/ | head -1
```

**Quiet dev warnings (stubs)**

```bash
mkdir -p dist/static dist/pages
printf "%s\n" "self.addEventListener('install',e=>self.skipWaiting());self.addEventListener('activate',e=>self.clients.claim());" > dist/static/serviceworker.js
printf "%s\n" "<!doctype html><meta charset=utf-8><title>500</title><h1>Temporary 500 page</h1>" > dist/pages/500.html
```

**Interpretation guide**

* `301` from `/index.html` → platform pretty redirect to `/`. Ensure directory form resolves via Grow routers (no custom middleware needed if router order is correct).
* `404` on pretty URL but `200` on explicit file → Grow output is fine; align router order/USE\_DIST\_FALLBACK or ensure the platform’s Grow routers are mounted as catch-all.

---

#### 8) “What Grow sees” (discovery vs render)

**(If available) route listing**
Some Grow builds ship `grow routes`. If present:

```bash
grow routes . | sed -n '1,200p'
```

Otherwise, infer from output files and sitemap.

---

#### 9) Git-whitelist awareness

If you see “Whitelist filtered out N routes” and only a subset renders:

* Touch the doc: `touch content/amp-dev/index.md` and rebuild; or
* Use `deploy` to render all routes (preferred for bring-up).

---

#### 10) Makefile probes (for amp.dev.4)

**Dry-run any target**

```bash
make -n build
```

**Override knobs on the fly**

```bash
make build POD_ROOT=pages OUT_DIR=dist/pages
make podspec NO_SITEMAP=1
```

**Verify target**

```bash
make verify PATH_CHECK=/en/amp-dev/index.html
```

---

#### 11) Quick file system macros

**Tree peek (2 levels)**

```bash
find pages -maxdepth 2 -type f | sort | sed -n '1,120p'
```

**Search for class definitions**

```bash
grep -RInE 'class\s+.*Extension' pages/extensions | sed -n '1,40p'
```

---

#### 12) Minimal rollback levers

* Disable sitemap during iteration:

  ```yaml
  sitemap: { enabled: no }
  ```
* Temporarily remove `{locale}` from a doc’s `$path` to prove rendering path:

  ```yaml
  $path: /amp-dev/index.html
  ```

---

#### 13) Known “red herrings” to ignore (dev)

* `pkg_resources is deprecated as an API` warning → harmless for Grow 2.2.3.
* Missing Google CSE key → only affects site search, not page routing.

---

#### 14) One-command sanity bundles

**Full clean + build + quick verify**

```bash
rm -rf dist/pages .cache && find . -type d -name '__pycache__' -exec rm -rf {} + && \
grow build . --out_dir=dist/pages && \
{ test -f dist/pages/sitemap_grow.xml && echo "sitemap OK" || echo "sitemap MISSING"; } && \
{ test -f dist/pages/en/amp-dev/index.html && echo "home OK" || echo "home MISSING"; }
```

**Run server + hit key endpoints (in another shell run the curls)**

```bash
USE_DIST_FALLBACK=1 NODE_ENV=local node platform/serve.js
```

---

that’s it — compact tools you can drop into your doc. if you want, i can also generate a tiny `tools/` folder (bash scripts) that wraps these probes as subcommands (`tools/yaml-check`, `tools/import-probe`, `tools/grow-build`, etc.) and wire them into your Makefile’s `verify` target.

