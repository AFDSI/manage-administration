awesome—here’s a compact “Instrumentation & Debugging Catalogue” pulled straight from what worked in this thread. Copy-paste friendly, each item says what it checks, how to run it, what “good” looks like, and what to do if it’s bad.

### Quick env & version sanity

**E1) Confirm Python/Grow via pyenv**

```bash
command -v pyenv && pyenv --version
python --version
grow --version
```

✅ Expect Python 3.9.x and grow 2.2.3 on PATH (via pyenv shims).
🛠 If grow can’t find extensions, ensure:

```bash
export PYTHONPATH="$PWD/pages"
```

**E2) Node & npm present**

```bash
node -v
npm -v
```

### Platform server bring-up

**S1) Start with explicit flags (dev)**

```bash
USE_DIST_FALLBACK=1 NODE_ENV=local node platform/serve.js
```

✅ Expect logs like:

```
[Platform] … Starting platform with environment local …
[DEV static] mounted /static from …/dist/static
[Platform] ✔ server listening on 8080!
```

🛠 If “Cannot access 'path' before initialization”, ensure `require('path')` is at top of `platform.js`.

**S2) Health-gated startup in scripts**

```bash
USE_DIST_FALLBACK=1 NODE_ENV=local node platform/serve.js &
PID=$!
until curl -fsS http://127.0.0.1:8080/__health-check >/dev/null; do sleep 0.5; done
echo "Platform up (pid $PID)"
```

### Lightweight HTTP probes (curl recipes)

**C1) Platform health**

```bash
curl -I http://127.0.0.1:8080/__health-check
```

✅ `200 OK` (small body).
ℹ Pretty-print health returns tiny Content-Length (e.g., 2/3 bytes) by design.

**C2) “Shell vs Raw” example page**

```bash
### Shell (should be large)
curl -sL -o /dev/null -w 'shell:%{http_code} bytes:%{size_download}\n' \
  http://127.0.0.1:8080/documentation/examples/components/amp-list/

### Raw (small, source file)
curl -sL -o /dev/null -w 'raw:%{http_code} bytes:%{size_download}\n' \
  'http://127.0.0.1:8080/documentation/examples/components/amp-list/?raw=1'
```

✅ Shell >> Raw (e.g., \~170KB vs 9.5KB).
🛠 If Shell == Raw or Shell is tiny, your dist pages aren’t being used; check `USE_DIST_FALLBACK` or Grow output.

**C3) First CSS/JS from shell is fetchable**

```bash
curl -sL http://127.0.0.1:8080/documentation/examples/components/amp-list/ \
 | grep -oE '/static/[^"]+\.(css|js)' | head -1 \
 | xargs -I{} curl -sI "http://127.0.0.1:8080{}" | sed -n '1,6p'
```

✅ `200 OK`.
🛠 `404` means `/static` isn’t mounted or assets missing. Verify `dist/static/` exists and look for “\[DEV static] mounted …” log line.

**C4) Localized roots (dist fallback)**

```bash
for p in /es/documentation/ /pt_br/documentation/ /ja/documentation/; do
  curl -sL -o /dev/null -w "$p -> HTTP:%{http_code} bytes:%{size_download}\n" \
    "http://127.0.0.1:8080$p"
done
```

✅ `200` with sizable bodies.
🛠 If `404`, Grow didn’t produce those locales or fallback disabled.

**C5) Embed routes canonicalization**

```bash
curl -I http://127.0.0.1:8080/documentation/examples/components/amp-list/embed
curl -I http://127.0.0.1:8080/documentation/examples/components/amp-list/embed/
```

✅ First is `301` → trailing slash; second should be `200` (or configured embed response).
🛠 If `404`, embed router/published path is missing.

**C6) “Pretty-print detector”**

```bash
curl -sI http://127.0.0.1:8080/documentation/ | awk '/HTTP|Content-Length/'
```

🔎 `Content-Length: 2/3` + `200` is the Pretty-print “{}”. That means Grow pages weren’t used for that path.

**C7) `/latest/` redirect sanity**

```bash
curl -sI http://127.0.0.1:8080/latest/ | sed -n '1,6p'
```

✅ `302 Found` with `Location: /documentation/`.

### Run-time logging & timing

**L1) Tiny timing middleware (already used)**
Add once near the end of `_configureMiddlewares()`:

```js
this.server.use((req, res, next) => {
  const t0 = process.hrtime.bigint();
  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - t0) / 1e6;
    const prefix = ms > 1000 ? 'CRITICAL_TIMING' : 'TIMING';
    console.log(`[${prefix}] ${req.method} ${req.originalUrl} ${ms.toFixed(1)}ms [${res.statusCode}]`);
  });
  next();
});
```

✅ Look for `TIMING` / `CRITICAL_TIMING` log lines to spot slow paths.

**L2) Startup warnings (benign)**

* “No Redis instances available. Falling back to LRU” — fine for local.
* “Missing Google Custom Search key” — only affects site search; safe to ignore during dev.

### Config & router checks

**R1) Verify host config quickly**

```bash
node -e "console.log(require('./platform/lib/config.js').hosts.platform)"
```

✅ Should show `http://localhost:8080`.

**R2) Dev example source mount (raw viewer)**
In `platform.js` (dev-only):

* static mount: `'/examples/sources' -> dist/examples/sources`
* conditional “raw” rewrite:

  * triggers on `?raw=1`, `?view=source`, or header `x-ampdev-examples-raw: 1`
  * otherwise falls through to shell or normal routers

**R3) Dist pages fallback guard**

* Enabled by `USE_DIST_FALLBACK=1` (and `NODE_ENV=local`)
* You should see logs:

  * `[DEV dist] dist pages fallback ENABLED` or `DISABLED`

### Grow build / artifacts sanity

**G1) Ensure stubs exist *before* bootstrap**

```bash
mkdir -p dist/static/samples dist/static/files
printf '{}\n' > dist/static/samples/samples.json
printf '{}\n' > dist/static/files/component-versions.json
printf '[]\n'  > dist/static/files/search-promoted-pages.json
```

(These avoid bootstrap/gulp steps failing on missing files.)

**G2) If gulp complains making the tar (packArtifacts)**
Create missing dirs:

```bash
mkdir -p .cache dist/pages
```

**G3) Manual Grow build (when gulp stalls after packArtifacts)**
From repo root where `podspec.yaml` exists:

```bash
export PYTHONPATH="$PWD/pages"
rm -rf dist/pages .cache
grow build . --out_dir=dist/pages --deployment=local
```

✅ Produces `dist/pages/**/index.html`.
🛠 If “Unable to find extension module …” set `PYTHONPATH` as above.

### Smoke tests (optional)

**T1) Run route smokes (if jest installed)**

```bash
APP_ENV=local PAGES_ORIGIN=http://127.0.0.1:8081 \
  npx jest smoke-tests/platform/Routes.test.js --forceExit --detectOpenHandles
```

🧭 Expect most routes `200`; failures often point to missing pages (e.g., pixi) or Grow output.

### Quick “symptom → probe → likely fix” map

* **Symptom:** Shell page is tiny or equals raw size.
  **Probe:** C2.
  **Fix:** Enable `USE_DIST_FALLBACK=1` or generate `dist/pages` with Grow.

* **Symptom:** CSS/JS 404 under `/static`.
  **Probe:** C3.
  **Fix:** Ensure `dist/static` exists; confirm “mounted /static” log; re-run `npm run bootstrap` if needed.

* **Symptom:** Pretty-print `{}` bodies on docs roots.
  **Probe:** C6.
  **Fix:** Generate `dist/pages`; ensure fallback enabled.

* **Symptom:** “extension module not found” when running Grow.
  **Probe:** G3.
  **Fix:** `export PYTHONPATH="$PWD/pages"`.

* **Symptom:** Gulp stops after `packArtifacts` with “Did you forget to signal async completion?”.
  **Probe:** G2/G3.
  **Fix:** Precreate `.cache` and `dist/pages`, or run Grow manually to completion.

---

If you want, I can turn this into a printable one-pager or a Makefile with `make health`, `make probe-shell`, `make grow-build`, etc.
