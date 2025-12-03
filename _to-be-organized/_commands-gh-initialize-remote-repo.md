
# TEMPLATE: Push local repo to GitHub AFDSI account

## Replace <repo-name> and <branch-name> with actual values

cd <repo-name>
git branch          # Confirm branch name
gh auth status      # Confirm authenticated
git remote -v       # Check current remote

## If remote exists and is wrong:
git remote set-url origin git@github.com:AFDSI/<repo-name>.git

## If no remote exists:
gh repo create AFDSI/<repo-name> --public --source=. --remote=origin --push

## If repo created but push failed:
git push -u origin <branch-name>

## Push without verifying
git push -u origin main --no-verify

