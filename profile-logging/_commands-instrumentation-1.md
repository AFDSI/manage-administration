here’s a compact, copy-pasteable **Testing Catalogue: Lightweight Instrumentation & Debugging** for your `amp.dev.4` local-dev flow. It’s designed to drop into your docs as-is.

### 0) Quick glossary

* **TASK markers**: start/finish breadcrumbs around gulp tasks.
* **Run log**: `logs/build-YYYYMMDD-HHMMSS.log` (rotating) + `build.log` (latest).
* **Grow logs**: command + cwd + exit code are appended to the same run log.
* **Smoke tests**: small CURL checks to confirm server health.
* **Guards**: preconditions that fail fast (e.g., tar integrity).

---

### 1) Gulp task instrumentation (TASK markers)

**Goal:** know exactly which task started/finished (or hung).

```js
// gulpfile.js/build.js (near the top)
const fs = require('fs');
const path = require('path');

// --- rotating run log chosen once per build ---
function nowStamp() {
  const d = new Date(), p = (n)=>String(n).padStart(2,'0');
  return `${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
const logsDir = path.resolve(process.cwd(), 'logs');
if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, {recursive:true});
const runLogFile = process.env.BUILD_LOG_FILE || path.resolve(logsDir, `build-${nowStamp()}.log`);
const latestLogFile = path.resolve(process.cwd(), 'build.log');
try { fs.writeFileSync(runLogFile, ''); fs.writeFileSync(latestLogFile, ''); } catch {}

function log(line) {
  const msg = `[${new Date().toISOString()}] ${line}`;
  console.log(msg);
  try { fs.appendFileSync(runLogFile, msg+'\n'); fs.appendFileSync(latestLogFile, msg+'\n'); } catch {}
}

function mark(name, fn) {
  return function wrapped(cb) {
    log(`[TASK] ${name} start`);
    const out = fn(cb);
    if (out && typeof out.then === 'function') {
      return out.finally(() => log(`[TASK] ${name} done`));
    }
    log(`[TASK] ${name} done`);
    return out;
  };
}
```

Wrap your series:

```js
exports.buildPages = function buildPages(done) {
  return gulp.series(
    mark('unpackArtifacts', unpackArtifacts),
    mark('buildFrontend', buildFrontend),
    mark('buildGrow', buildGrow),         // or your equivalent
    mark('minifyPages', minifyPages),
    mark('copyBuildFiles', copyBuildFiles),
    mark('sharedPages', sharedPages)
  )(done);
};
```

---

### 2) Grow subprocess logging

**Goal:** see the exact Grow command, cwd, and exit code.

```js
// platform/lib/utils/grow.js
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const runLogFile = process.env.BUILD_LOG_FILE || path.resolve(process.cwd(), 'build.log');
function log(line){
  const msg = `[${new Date().toISOString()}] ${line}`;
  console.log(msg);
  try { fs.appendFileSync(runLogFile, msg+'\n'); } catch {}
}

module.exports = function grow(command, options = {}) {
  return new Promise((resolve, reject) => {
    const args = command.split(' ');
    const cwd = options.cwd || process.cwd();
    log(`[GROW] Running: grow ${args.join(' ')} in ${cwd}`);
    const child = spawn('grow', args, { cwd, stdio: 'inherit' });
    child.on('exit', (code) => {
      log(`[GROW] Exited with code ${code}`);
      code === 0 ? resolve() : reject(new Error(`Grow exited with code ${code}`));
    });
  });
};
```

---

### 3) Artifact integrity guard (fail fast)

**Goal:** prevent “async completion” stalls from a bad archive.

* **Pack** as gzip (match `.gz`):

```bash
tar -czf artifacts/setup.tar.gz \
  ./pages/content/ ./pages/shared/ ./dist/ \
  ./boilerplate/lib/ ./boilerplate/dist/ \
  ./playground/dist/ ./frontend21/dist/ \
  ./.cache/ ./examples/static/samples/samples.json
```

* **Check** before unpack:

```bash
gzip -t artifacts/setup.tar.gz || { echo "❌ setup.tar.gz not gzip"; exit 1; }
tar -tzf artifacts/setup.tar.gz | head || { echo "❌ cannot list setup.tar.gz"; exit 1; }
```

* **Unpack**:

```bash
tar -xzf artifacts/setup.tar.gz -C .
```

*(If you must keep bzip2, rename to `.tar.bz2` and use `-j` consistently.)*

---

### 4) Step-by-step isolation (manual pipeline)

**Goal:** find the first failing gulp task.

```bash
### after ensuring a valid artifacts/setup.tar.gz
npx gulp unpackArtifacts
npx gulp buildFrontend
### if you have a dedicated Grow task, else skip (often inside buildPages)
### npx gulp buildGrow
npx gulp minifyPages
npx gulp copyBuildFiles
npx gulp sharedPages
```

**Rule:** only run the next step if the previous one completes.

---

### 5) Server asset fallback (dev-only)

**Goal:** avoid 404/500 for missing `dist/static/*` during local dev.

**Option A — run without dist fallback**

```bash
NODE_ENV=local node platform/serve.js
```

**Option B — add dev fallbacks in the server**

```js
// platform/lib/platform.js (in start function, for dev only)
if (process.env.NODE_ENV === 'local' || process.env.DEV_ASSET_FALLBACK === '1') {
  const root = path.resolve(__dirname, '../..');
  app.use('/static', express.static(path.join(root, 'dist/static'), { fallthrough:true }));
  app.use('/static', express.static(path.join(root, 'frontend21/dist'), { fallthrough:true }));
  app.use('/static', express.static(path.join(root, 'pages/static'), { fallthrough:true }));
  app.get('/serviceworker.js', (req,res)=>{
    res.type('js').send('// noop sw for local\nself.addEventListener("install",()=>{});\nself.addEventListener("activate",()=>{});');
  });
}
```

---

### 6) Dev bootstrap (stubs & essential copies)

**Goal:** silence noisy 404s without touching prod.

```bash
### samples.json
install -D examples/static/samples/samples.json dist/static/samples/samples.json

### manifest (if you have one in pages)
test -f pages/static/manifest.json && install -D pages/static/manifest.json dist/static/manifest.json

### noop service worker (local only)
mkdir -p dist/static
cat > dist/static/serviceworker.js <<'JS'
self.addEventListener('install', ()=>{});
self.addEventListener('activate', ()=>{});
JS

### images/fonts from either pages or frontend build outputs
mkdir -p dist/static/img dist/static/fonts
[ -d pages/static/img ] && cp -r pages/static/img/* dist/static/img/ 2>/dev/null || true
[ -d frontend21/dist/img ] && cp -r frontend21/dist/img/* dist/static/img/ 2>/dev/null || true
[ -d pages/static/fonts ] && cp -r pages/static/fonts/* dist/static/fonts/ 2>/dev/null || true
[ -d frontend21/dist/fonts ] && cp -r frontend21/dist/fonts/* dist/static/fonts/ 2>/dev/null || true
```

*(Wrap those into a `dev-bootstrap` gulp task later.)*

---

### 7) Environment sanity checks

**Goal:** rule out trivial env misconfig.

```bash
node -v
npm -v
npx gulp -v
node -e "require('module-alias/register');console.log(require.resolve('@lib/utils/grow'))"
echo "GROW_ENV=$GROW_ENV GROW_POD_DIR=$GROW_POD_DIR"
```

* Prefer **podspec at `pages/podspec.yaml`**; else set `GROW_POD_DIR=platform/config`.

---

### 8) Smoke tests (server up?)

**Goal:** quick health probes (paste into your doc).

```bash
### platform responds
curl -sI http://127.0.0.1:8080/ | head -n1

### example source file (rewrite sanity)
curl -sI http://127.0.0.1:8080/examples/sources/components/amp-list.html | head -n1 || true

### docs section
curl -sI http://127.0.0.1:8080/documentation/ | head -n1
```

---

### 9) Parse timings (where did time go?)

**Goal:** extract task durations from `build.log`.

```bash
grep "Finished '" build.log | \
  sed -E "s/.*Finished '([^']+)' after ([^ ]+) .*/\1\t\2/" | \
  column -t -s $'\t'
```

*(You’ll see lines like `optimizeFiles  2.3 h`, `sitemap  2.11 s`, `buildPages  3.93 h`.)*

---

### 10) Makefile targets (repeatable loop)

**Goal:** one-liners to build/serve/test and keep logs.

```make
SHELL := /bin/bash
NODE_ENV ?= local
LOGDIR := logs
STAMP := $(shell date +%Y%m%d-%H%M%S)
RUNLOG := $(LOGDIR)/build-$(STAMP).log

.PHONY: clean build serve dev-smoke timings quick

clean:
	rm -rf dist .cache artifacts build.log
	mkdir -p $(LOGDIR)

build: clean
	BUILD_LOG_FILE=$(RUNLOG) npx gulp buildPages
	@cp -f $(RUNLOG) build.log || true
	@echo "Log: $(RUNLOG)"

serve:
	NODE_ENV=$(NODE_ENV) node platform/serve.js

dev-smoke:
	@curl -sI http://127.0.0.1:8080/ | head -n1
	@curl -sI http://127.0.0.1:8080/documentation/ | head -n1
	@curl -sI http://127.0.0.1:8080/examples/sources/components/amp-list.html | head -n1 || true

quick: clean
	SKIP_OPTIMIZE=1 BUILD_LOG_FILE=$(RUNLOG) npx gulp buildPages
	@cp -f $(RUNLOG) build.log || true
```

---

### 11) Performance quick wins (local only)

* **WSL**: develop under `/home/...` (not `/mnt/c`), boost via `.wslconfig`:

  ```
  [wsl2]
  memory=16GB
  processors=8
  sparseVhd=true
  ```

  Then `wsl --shutdown`.
* **Windows Defender**: exclude your project dir and WSL VHD from real-time scan.
* **Caching**: image/minify tasks should skip unchanged files (`gulp-newer` / content-hash cache).
* **Concurrency**: use bounded parallelism (6–8 workers) to avoid disk thrash.

---

### 12) Troubleshooting decision tree (fast triage)

1. **Build stalled with “Did you forget to signal async completion?”**
   → Check **artifact integrity** (gzip guard). If good, the next likely culprit is a gulp task `await`-ing a stream. Patch to **return the stream/Promise**.

2. **Grow fails “Pod not found in pages/podspec.yaml”**
   → Copy `platform/config/podspec.yaml` → `pages/podspec.yaml`, or set `GROW_POD_DIR=platform/config`.

3. **Highlights extractor error (`list` has no `get`)**
   → Local stub `platform/config/search-promoted-pages.json` with a `"default"` object key.

4. **404/500 for static assets**
   → Run server without dist fallback (`NODE_ENV=local`), or add **dev static fallbacks** / `dev-bootstrap` copies/stubs.

5. **Local way slower than CI**
   → Skip `optimize` once to confirm bottleneck; enable caching; adjust WSL/Defender as above.

---

This catalogue should cover 95% of the “where did it hang?” and “why is it failing only locally?” questions, with minimal code churn and quick reversibility.
