Short answer: you don’t need to change `profile-generator.ps1` for this.

Your debug run used `-NoProfile`, so the generated profile never ran.
That’s why PATH starts with `WindowsApps` instead of our four managed entries.
Let’s make `profile-debug.ps1` **self-contained**: it will dot-source the generated profile at the start of the run and then check PATH/tools. 
We’ll also fix the token warning to only trigger on real `${…}` tokens.

Here are precise patchlets.

---

# Patch 1 — Make the debug script load the generated profile

**Find (near the top, after the parameter block):**

```powershell
if (-not (Test-Path -LiteralPath $Generated)) {
  Err "Generated profile not found: $Generated"
  exit 1
}
```

**Insert immediately AFTER that block:**

```powershell
# Ensure we evaluate the same environment the shell would have after startup:
# dot-source the generated profile in THIS process before we inspect PATH.
try {
  . $Generated
} catch {
  Err "Failed to dot-source generated profile: $($_.Exception.Message)"
  exit 1
}
```

Now `profile-debug.ps1` works even when you launch it with `-NoProfile`.

---

# Patch 2 — Fix the “unresolved token” warning

**Find:**

```powershell
if ($txt -match '\$\{[^\}]+\}') {
  Warn "Found unresolved token(s) like \${...} in generated file."
}
```

If your copy shows a different regex or produced `like \` in the message, **replace the whole block** with exactly the snippet above. That regex only fires when literal `${…}` placeholders remain, not for normal backslashes in Windows paths.

---

# Patch 3 — (Optional) Show exactly what tokens were found

If you want more detail when tokens exist, add this line right after the warning block:

```powershell
($txt | Select-String -Pattern '\$\{[^}]+\}' -AllMatches).Matches.Value | Sort-Object -Unique | ForEach-Object { "  -> $_" }
```

---

# What to expect after the patches

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\profile-debug.ps1
```

Now the script will:

1. Dot-source `E:\users\gigster\workspace\dev\profiles\ps\profile.generated.ps1` in the current process,
2. Rebuild PATH using our strict ordering,
3. Then report PATH head and tool resolution.

Your PATH “front” should read:

```
E:\users\gigster\workspace\dev\tools\python-bin
E:\users\gigster\workspace\dev\tools\nodejs
E:\users\gigster\workspace\dev\bin
E:\users\gigster\workspace\dev\tools
```

…and both `node` and `python` should resolve under `E:\users\gigster\workspace\dev\tools\...`.

---

## Why we’re not changing `profile-generator.ps1` here

* The generator already emits a **strict PATH rebuild** (`Set-PathFront`) inside the generated profile.
* Your previous run with a normal PowerShell session showed node/python correctly resolving from portable locations; the “WindowsApps first” line appeared only when you ran the debug tool with `-NoProfile` (which deliberately skips all profiles).
* By letting the debug tool **dot-source** the generated profile itself, we validate exactly what a normal login shell would set—without relying on your user profile being loaded.

If, after these patches, PATH still doesn’t start with those four entries, tell me and I’ll provide a small diagnostic snippet to print the **ordered list** embedded in `profile.generated.ps1` and the **raw PATH** before/after the rebuild so we can pinpoint the mismatch.
