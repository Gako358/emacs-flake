---
name: github
description: Draft concise GitHub issues and subissues with conventional titles.
---

Write GitHub issues that are brief, actionable, and easy to scan.

- Use a lowercase conventional title: `<type>/<scope>: <imperative summary>`.
- Prefer `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `build`, or `ci`; choose a short scope such as `auth`, `api`, or `eca`.
- Keep the body to the fewest lines that preserve intent. Do not repeat the title, add background that does not affect implementation, or paste research logs.
- Include only relevant sections: problem/goal, acceptance criteria, constraints or non-goals, and verification.
- Make acceptance criteria observable and use short checklists.
- Create subissues only for independently trackable work. Each subissue must have one outcome, name its parent, avoid duplicating the parent body, and use the same title convention.
- Keep the parent focused on shared outcome and integration criteria; link child issues with GitHub's supported parent/subissue mechanism when available.
- Confirm repository and labels before invoking `gh`. Use `gh issue create` for creation and report URLs. Never create duplicates silently.

Example issue:

```markdown
Title: feat/auth: add passkey sign-in

Support passkeys alongside password login.

- [ ] Users can register and remove a passkey
- [ ] Sign-in falls back to the existing password flow
- [ ] Authentication tests pass
```

Example subissue:

```markdown
Title: test/auth: cover passkey fallback

Parent: #123

- [ ] Cover unavailable and rejected passkey flows
- [ ] Existing password tests remain green
```
