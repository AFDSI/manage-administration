Here’s a tightened, repeatable handoff flow you can standardize:

# The transition flow (repeat per task)

1. **Summarize in ChatGPT-5/Win-10**
   Ask me for a *Handoff Pack* at the end of a chat: goals, constraints, file paths, commands, acceptance tests, and “don’ts.” Keep it brief and actionable.

2. **Commit the handoff into the repo**
   Save that text as `docs/codex/code_spec.md` (or one file per task like `docs/codex/2025-09-23-task-name.md`). Codex is best when the context lives **in files** it can read and edit.

3. **Open the repo in Codex**
   Tell Codex: “Read `docs/codex/code_spec.md` and start from there.” Now Codex can navigate the tree, edit files, run tests, and make PRs aligned to the spec.

4. **Track decisions & deltas**
   Have Codex append an ADR (architecture decision record) to `docs/adr/ADR-YYYYMMDD-<topic>.md` after each meaningful change. This preserves context across sessions.

5. **Close the loop in ChatGPT-5/Win-10 (optional)**
   If you need broader reasoning/docs, paste Codex’s diffs back here and I’ll produce a new *Handoff Pack* for the next Codex iteration.

---

# Minimal `code_spec.md` template

````md
# Code Spec — <Task Name>
Date: 2025-09-23
Repo: <local path or Git URL>, Branch: <name>

## Goal
<One paragraph with the outcome, not the steps.>

## Scope
- Files: <relative paths>
- Components/Modules: <names>
- In/Out of scope: <bullets>

## Constraints
- OS/Runtime: Win10 + WSL (Debian), Node v18/22, Python 3.9.18
- No-JS in templates (user preference), Grow 2.2.3, AMP dev ports 8080–8084
- Paths on /mnt/e/… (primary), AWS S3 for assets, Netlify for preview
- Style: BEM SCSS; YAML/Jinja2; CSV/TSV outputs where noted

## How to Run
```bash
# example
npm run dev:gateway
npm run dev:pages
pytest -q
````

## Test Oracle / Acceptance Criteria

* <User-visible behavior or CLI output>
* \<URL responds 200 and renders X>
* \<Unit test/CI job passes>

## Don’ts

* \<e.g., Do not modify /platform/lib/router.js routing order>
* \<e.g., Avoid CDN domain swap logic in dev>

## Open Questions

* <short list>

````

---

# Example (tailored to your stack)

```md
# Code Spec — AMP examples rewrite mapping
Date: 2025-09-23
Repo: /mnt/e/repos/amp.dev.5, Branch: feat/examples-rewrite

## Goal
Serve `/documentation/examples/components/:name/` by rewriting to `/dist/examples/sources/components/:name.html`, preserving current dev ports and working in WSL & Win10.

## Scope
- Edit: platform/lib/platform.js (static mount for /examples/sources)
- Edit: platform/config/dev-rewrites.json (mapping rules)
- Verify: pages pod (8081) & platform pod (8082) both respond 200

## Constraints
- Node 18 (dev), Grow 2.2.3, Debian WSL
- Paths pinned to `/mnt/e/…`
- No changes to Prod CDN config

## How to Run
```bash
npm run dev:gateway
npm run dev:platform
curl -I http://localhost:8080/documentation/examples/components/amp-list/
````

## Acceptance

* `/documentation/examples/components/amp-list/` returns 200
* HTML contains built example from `/dist/examples/sources/components/amp-list.html`

## Don’ts

* Do not modify playground (8083) or preview (8084)

```

---

# Folder convention (keeps Codex tidy)

```

/docs
/codex
code\_spec.md              # current task
2025-09-23-examples.md    # past tasks
/adr
ADR-2025-09-23-rewrites.md

````

---

# Quick Win (PowerShell helper)

Create a timestamped spec file from your clipboard (paste a ChatGPT “Handoff Pack” then run this):

```powershell
$root = "E:\repos\amp.dev.5"
$dir  = Join-Path $root "docs\codex"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$path  = Join-Path $dir "$stamp-code_spec.md"
(Get-Clipboard) | Out-File -FilePath $path -Encoding UTF8 -NoNewline
git -C $root add $path
git -C $root commit -m "docs(codex): add $stamp code_spec"
Write-Host "Created $path and committed."
````

---

# Pitfalls to avoid

* **Chat-only context**: if it’s not in the repo, Codex can’t reliably reuse it later. Promote decisions/tests into files.
* **Ambiguous acceptance criteria**: give Codex a test oracle (command output, URL, log line) so it knows when it’s “done.”
* **Environment drift**: pin versions in the spec and reference your `env-config.yaml` so Codex doesn’t “upgrade” toolchains mid-task.

---

If you want, tell me the first ChatGPT-5 thread you’d like to migrate and I’ll produce a compact *Handoff Pack* ready to paste into `docs/codex/code_spec.md`.
