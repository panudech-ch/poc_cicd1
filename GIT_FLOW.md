# Git Flow Standard

> The central standard document for every project (old and new), all on the same Git Flow.
> Each project references this file instead of writing its own GIT_FLOW.
>
> Version: 1.7.1 · Updated: 2026-08-23

---

## 0. Philosophy

- One standard that every project uses -> less rule-juggling across projects, faster onboarding.
- Use Full Git Flow the same way in every project — no exceptions, for consistency.
- This document defines the central rules. The project-specific build/deploy part goes in
  each repo's own `GIT_FLOW.local.md` (see section 7).

---

## 1. Branch Structure

```
main (production — the code users actually run)
  ^
release/vX.X.X (QA & final testing)
  ^
develop (integration — collects finished features)
  ^
feature/xxx (development)
```

> The standard fixes `main` as the production branch in every project (no longer a choice).
> Old repos still on `master` should migrate to `main` gradually (case by case). Until the
> move is done, record the real name in that repo's `GIT_FLOW.local.md`.

---

## 2. Branch Naming Convention (central — identical in every project)

| Type | Format | Example | Used when |
|------|--------|---------|-----------|
| Feature | `feature/short-description` | `feature/inspection-template` | Developing a new feature |
| Release | `release/vX.X.X` | `release/v3.4.0` | Preparing a release (Full only) |
| Hotfix | `hotfix/vX.X.X` | `hotfix/v3.4.2` | Urgent production bug fix |
| Bugfix | `bugfix/short-description` | `bugfix/login-error` | Fixing a bug during dev |
| Defect | `defect/short-description` | `defect/multiple-list-error` | Fixing a defect QA found |
| Docs | `docs/short-description` | `docs/single-device-session` | Docs/spec/POC (no code) |
| Spike | `spike/short-description` | `spike/otp-poc` | Technical experiment/research |
| Schema | `schema/short-description` | `schema/user-table` | Database/API schema change |

Naming rules:
- Use kebab-case (lowercase, `-` separated) for the description.
- Keep the description short and meaningful — about 4 words max.
- Docs/planning/POC phases with no code yet use `docs/*` or `spike/*` (not `feature/*`).

---

## 3. Commit Message Convention (central)

```
<type>: <subject>

<body if needed>
```

### Types
| type | Used when |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting (no logic change) |
| `refactor` | Code restructure (no behavior change) |
| `test` | Add/fix tests |
| `chore` | Maintenance (bump version, deps, config) |

### Rules
- Language: commit messages are English only (both subject and body) — no other language.
  This keeps them universally readable, tooling/CI-friendly, and consistent across projects.
- subject: start with an imperative verb (e.g. `add`, `fix`, `update`), no trailing period.
- Keep it short: subject <= 50 chars. Add a body only when the change needs explaining, and
  keep it to a few lines — not paragraphs.
- Reference a requirement id when there is one (traceability): put `REQ-xxx` in the subject
  or body, e.g. `feat: block second device on login (REQ-002)`.
- One commit = one coherent change.

---

## 4. Standard Flow

### 4.0 Starting work — branch first, then implement

> Always create the branch first, then start editing — never edit on `develop`/`main`
> directly and create the branch afterward.
> Correct order: checkout the new branch -> then implement (not implement first, branch later).
> Before typing the first line of code, check you are on the right branch
> (`git branch --show-current` or `gitflow check`).

```bash
# Before every new task (do this before editing any file):
git checkout develop
git checkout -b feature/<short-desc>   # code=feature/ · docs=docs/ · bug fix=bugfix/
gitflow check                          # confirm the branch name is right before starting
# ^ once it passes, start editing
```

> Already edited on `develop` (not committed yet)? Move the work to a new branch:
> `git stash` -> `git checkout -b feature/<desc>` -> `git stash pop`

### 4.0.1 Before commit — review first, enforced by a pre-commit hook

> Every commit must be reviewed first: show the full diff -> wait for the owner's approval
> -> then commit.
> Never bundle commit + merge + delete branch before the owner has seen the diff.

The standard enforces this with a pre-commit hook (emitted by `gitflow hook` — a single
source in the binary, no logic copied into each repo). The hook blocks a commit when:

1. On `main` / `develop` directly (branch first — section 4.0).
2. The branch name violates naming (section 2) — the hook runs `gitflow check` for you
   (skipped if `gitflow` is not installed on the machine).
3. No approval token — the owner has not reviewed + approved the diff yet.

Correct flow: show the full diff -> owner approves -> `touch .git/COMMIT_APPROVED` -> commit.
The token is single-use (the hook deletes it after it passes) — the next commit needs a
fresh approval.

```bash
# Install once per clone (needs gitflow on PATH):
gitflow hook > .githooks/pre-commit && chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

> Never use `--no-verify` — it bypasses the entire review gate (against the standard).
>
> Primary hook / secondary hook: git runs a single `pre-commit` file — the file from
> `gitflow hook` is the primary hook (the 3 central gates above), do not edit it by hand.
> Repo-specific rules (e.g. checking a Status value against a file in the repo) go in
> `.githooks/pre-commit.local` — the primary hook calls it automatically.

### 4.1 Feature -> Develop

> Once committed = merge into develop right away, in the same step — never leave a feature
> branch hanging.
> A feature branch is only a temporary workspace. When the work is committed, merge it back
> into develop and delete the branch immediately (one flow).
> A committed-but-unmerged branch makes it confusing later where the work actually is.

```bash
# Right after committing on feature/xxx, continue immediately:
git checkout develop
git merge feature/xxx --no-ff -m "Merge feature/xxx into develop"
git branch -d feature/xxx
```

> Applies to every temporary branch (`feature/` `docs/` `bugfix/` `defect/` `spike/` `schema/`):
> commit -> merge -> delete.

### 4.2 Develop -> Release
```bash
git checkout develop
git checkout -b release/vX.X.X
# In release: final QA, bug fixes, bump version, update changelog
git commit -am "chore: bump version to X.X.X"
```

### 4.3 Release -> Main + Tag
```bash
git checkout main
git merge release/vX.X.X --no-ff -m "Merge release/vX.X.X into main"
git tag -a vX.X.X -m "Release vX.X.X: <main summary>"   # always annotated
```

### 4.4 Release -> Develop (merge back)
```bash
git checkout develop
git merge release/vX.X.X --no-ff -m "Merge release/vX.X.X back into develop"
git branch -d release/vX.X.X
```

### 4.5 Hotfix (branch from main only)
```bash
git checkout main
git checkout -b hotfix/vX.X.X
# fix the bug + bump version
git commit -am "fix: <bug>"
git checkout main && git merge hotfix/vX.X.X --no-ff -m "Merge hotfix/vX.X.X into main"
git tag -a vX.X.X -m "Hotfix vX.X.X: <summary>"
git checkout develop && git merge hotfix/vX.X.X --no-ff -m "Merge hotfix/vX.X.X back into develop"
git branch -d hotfix/vX.X.X
```

> Why hotfix branches from `main`: main = the real production (single source of truth).
> `release/*` is temporary/deleted, and `develop` may hold features not yet through QA.

---

## 5. Tag / Versioning (central — SemVer)

```
vMAJOR.MINOR.PATCH
```
| Part | Bump when |
|---|---|
| MAJOR | breaking changes |
| MINOR | new feature (backward compatible) |
| PATCH | bug fix |

- Always use an annotated tag (`git tag -a`) — it records author/date/message.
- Build/deploy from a tag, not a branch.

---

## 6. Summary Diagram

```
feature/xxx ------+
                  v
              develop <------------------+
                  v                      |
           release/vX.X.X ---------------+ (merge back)
                  v                      |
              main <-- tag vX.X.X        |
                  v                      |
            hotfix/xxx -------------------+
```

---

## 7. Project-Specific Part (goes in GIT_FLOW.local.md)

What is NOT in the central standard because it differs per project — each repo writes it in
its own `GIT_FLOW.local.md`:

- The real production branch name (the standard is `main`; recorded in case an old repo is
  still `master` mid-migration).
- How to build & deploy (e.g. Flutter `fvm flutter build`, Node `npm run build` + pm2).
- Version file location (e.g. `pubspec.yaml`, `package.json`).
- Patch note / store submission (mobile).
- Secrets/keys that need local config.
- Stack-specific troubleshooting.

> In a repo, keep a short `GIT_FLOW.md` that points to this central standard + links
> `GIT_FLOW.local.md`.

---

## 8. Adopting it in a Project

### New project
1. Create `GIT_FLOW.local.md` with the project-specific part (production branch, build/deploy).
2. In the repo's `GIT_FLOW.md`, reference this central standard.

### Existing project (has an old GIT_FLOW)
- Cut the "central" part (branch/naming/commit/tag/flow) out -> point to this standard instead.
- Keep only the build/deploy part in `GIT_FLOW.local.md`.
