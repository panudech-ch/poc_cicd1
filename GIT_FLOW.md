# Commit Message Convention

```
<type>: <subject>

<body if needed>
```

## Types

| type | Used when |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting (no logic change) |
| `refactor` | Code restructure (no behavior change) |
| `test` | Add/fix tests |
| `chore` | Maintenance (bump version, deps, config) |

## Rules

- Language: commit messages are English only (both subject and body) — no other language.
  This keeps them universally readable, tooling/CI-friendly, and consistent across projects.
- subject: start with an imperative verb (e.g. `add`, `fix`, `update`), no trailing period.
- Keep it short: subject <= 50 chars. Add a body only when the change needs explaining, and
  keep it to a few lines — not paragraphs.
- Reference a requirement id when there is one (traceability): put `REQ-xxx` in the subject
  or body, e.g. `feat: block second device on login (REQ-002)`.
- One commit = one coherent change.
