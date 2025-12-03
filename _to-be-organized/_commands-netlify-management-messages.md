
## Step 1: Confirm the correct site ID

In a local terminal:

```
netlify sites:list
```

Find your real site ID for site from platform.json

## ✔ Step 2: Verify the token has access

Use your token locally:

```
netlify status --auth <YOUR_TOKEN>

```

If it returns:

```
No site found
```

then the token is *not associated with the team that owns the site*.

Fix: Generate a new token from the correct team:

⚙ Netlify UI → Team → User Settings → Applications → "New access token"

---

## ✔ Step 3: Ensure GitHub Actions is using the correct token

Check:

`Settings → Secrets → Actions → NETLIFY_AUTH_TOKEN`

If outdated or copied from a different account → replace it.

---

# **How to Fix Inside GitHub Actions**

### Update your deploy step:

```yaml
- name: Deploy to Netlify
  run: |
    npx netlify deploy \
      --prod \
      --auth "$NETLIFY_AUTH_TOKEN" \
      --dir "dist/pages" \
      --site "$NETLIFY_SITE_ID"
  env:
    NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
```

Make sure both are correct.

---


# **Most Likely Cause Given Your Environment**

Since you are generating tokens via:

```
secrets-build.ps1 emit
```

… it is highly likely that:

➡ The *wrong token* got generated or selected from `.env.secrets`
➡ It does not belong to the team that owns *staging-amp-dev.netlify.app*

This is extremely common when:

* tokens are rotated during testing,
* migrations occur between GitHub repos,
* the token is saved under the wrong team in Netlify,
* or Netlify silently invalidates PATs during account changes.

---

# ⚡ Recommended Action (Simplest Path)

1. Log into Netlify **as the team owner**.

2. Generate a **new personal access token**.

3. Copy the real site ID from Netlify UI.

4. Update GitHub secrets:

```
NETLIFY_AUTH_TOKEN
NETLIFY_SITE_ID
```

5. Re-run the workflow.

This resolves the issue **99% of the time**.

