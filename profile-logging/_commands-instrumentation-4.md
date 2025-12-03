Here’s a collection of **lightweight instrumentation and debugging code structures** you’ve encountered or can embed across `amp.dev` components. These are ready for inclusion in your **Instrumentation Catalogue**.

---

## ✅ 1. Instrumenting Node.js Platform

### A. **Console Logging in Routers**

Use inside `platform/lib/routers/*.js`:

```js
console.log('[ROUTER] Received request:', req.originalUrl);
```

To log when proxying to Grow:

```js
console.log('[PROXY → GROW] Forwarding to Grow:', req.url);
```

---

### B. **Middleware Entry Logging**

In `platform.js` or any custom middleware:

```js
app.use((req, res, next) => {
  console.time(`[TIMER] ${req.method} ${req.url}`);
  res.on('finish', () => {
    console.timeEnd(`[TIMER] ${req.method} ${req.url}`);
  });
  next();
});
```

---

### C. **Debug Log (Optional: Controlled by ENV)**

```js
if (process.env.DEBUG === 'true') {
  console.debug('[DEBUG] Response headers:', res.getHeaders());
}
```

Enable with:

```bash
export DEBUG=true
```

---

## 🧪 2. Debugging Grow (Python)

### A. **Enable Verbose Grow Build**

```bash
grow build --verbose
```

Or, export inside a script:

```bash
export GROW_ENV=local
grow run --port=8081
```

---

### B. **Log Template Context**

Inside a `.html` or `.j2` template:

```jinja2
{# DEBUG: Output entire context #}
<pre>{{ this | pprint }}</pre>
```

Or for selective debugging:

```jinja2
{% if g.debug %}<pre>{{ g.request.path }}</pre>{% endif %}
```

Enable `g.debug` by modifying the Grow podspec or injecting a fake request header.

---

## 🔍 3. File System + Static Asset Inspection

### A. **Directory Tree Dumps**

From WSL:

```bash
tree dist/ > _tree-dist.txt
ls -lhR dist/static > _static-assets.txt
```

Or in PowerShell:

```powershell
Get-ChildItem -Recurse dist\ | Format-List > _dist-manifest.txt
```

---

## 🧪 4. WSL + CI Debugging Helpers

### A. **Confirm Grow Server Reachability**

From within Node.js (via axios or fetch):

```js
const axios = require('axios');
axios.get('http://localhost:8081/documentation/components/index.html')
  .then(res => console.log('[GROW RESPONSE]', res.status))
  .catch(err => console.error('[GROW ERROR]', err.message));
```

---

## 🧹 5. Test Failures + Missing Module Traps

### A. **Catch Exports in Gulp Tasks**

Example failure:

```js
exports.buildPixiFunctions = buildPixiFunctions; // ❌ ReferenceError
```

→ Guard with:

```js
if (typeof buildPixiFunctions === 'function') {
  exports.buildPixiFunctions = buildPixiFunctions;
}
```

---

### B. **Check for Jest Config Errors**

Use this pattern when pruning:

```js
// globals: {
//   AMP_DEV_PIXI_APIS_KEY: '', // remove if unused
// },
```

---

Would you like this exported as `.md`, `.tsv`, or `.sh` for inclusion in your Instrumentation Catalogue?
