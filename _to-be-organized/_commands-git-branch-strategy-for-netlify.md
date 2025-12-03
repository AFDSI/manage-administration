
## Correct Approach:
1. Build and deploy `main` branch to Netlify first (baseline)
2. Create local branches for each page (`feature/page-1`, `feature/page-2`, etc.)
3. Push branches to GitHub
4. Eventually merge all tested branches into `main`
5. Rebuild `main` on Netlify with all changes

### Option 1: Use Netlify Branch Previews (Recommended)

```bash
# Local workflow
cd amp.dev.20
git checkout -b feature/page-1
# ... make changes to page 1 ...
git add . && git commit -m "Add page 1"
git push -u origin feature/page-1

# Netlify automatically creates preview URL:
# https://feature-page-1--your-site.netlify.app
# Main site stays unchanged at: https://your-site.netlify.app
```

**Benefits:**
- `main` deployment stays stable
- Each branch gets its own preview URL
- Test each page independently without affecting production
- No overwrites

**Netlify Setup:**
- Enable "Branch deploys" in Netlify settings
- Set to "All" or "Let me add individual branches"

## Better Workflow

```bash
# 1. Deploy main to production
git checkout main
git push origin main
# Netlify builds: https://your-site.netlify.app

# 2. Create feature branches for each page
git checkout -b feature/page-1
# ... work on page 1 ...
git push origin feature/page-1
# Netlify preview: https://feature-page-1--your-site.netlify.app

git checkout main
git checkout -b feature/page-2
# ... work on page 2 ...
git push origin feature/page-2
# Netlify preview: https://feature-page-2--your-site.netlify.app

# 3. Test each branch independently via preview URLs

# 4. Merge branches to main one by one (or all at once)
git checkout main
git merge feature/page-1
git merge feature/page-2
git push origin main
# Production updates with all changes
```

