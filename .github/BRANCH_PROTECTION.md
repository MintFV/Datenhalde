# Branch protection: instructions and example commands

This file contains a minimal recommended branch protection policy and commands
you can run as a repository admin to apply it. Applying protection requires
repository admin permissions.

Recommended rule for branch `refactorPED` (adapt to your naming):

- Require pull request reviews before merging (1 required approval)
- Dismiss stale pull request approvals when a new commit is pushed
- Require code owner reviews (requires a valid `CODEOWNERS` file)
- Require status checks to pass before merging (use the CI workflow names)
- Enforce for administrators (optional)

Web UI (quick):

1. Go to `Settings` → `Branches` → `Add rule`.
2. Set `Branch name pattern` to `refactorPED` (or `main`/`master`).
3. Enable:
   - `Require pull request reviews before merging` (set `1` approval)
   - `Require review from Code Owners`
   - `Require status checks to pass before merging` and select the CI checks (e.g. `lint`, `node-smoke`)
   - `Include administrators` if you want enforcement for admins
4. Save changes.

CLI/API example (uses `gh` or `curl` with a token). Replace placeholders.

Using `gh` (must be authenticated):

```bash
# Example: create a JSON file `branch-protection.json` with the payload below,
# then upload it with gh api.
cat > branch-protection.json <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI / lint & type-check", "Playwright smoke tests"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null
}
JSON

gh api -X PUT /repos/MintFV/Datenhalde/branches/refactorPED/protection \
  -F file=@branch-protection.json
```

Using `curl` (requires `GITHUB_TOKEN` environment variable with repo admin scope):

```bash
curl -X PUT \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/MintFV/Datenhalde/branches/refactorPED/protection \
  -d @branch-protection.json
```

Notes:
- The `contexts` array must match the exact check names that appear in the
  GitHub Checks UI. If unsure, set an empty list and enable required status
  checks via the web UI instead.
- The `gh api` / `curl` approaches require admin rights or a token with
  `repo` scope. Use the web UI if you prefer not to manage tokens.
