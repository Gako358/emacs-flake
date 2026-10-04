---
name: github
description: Draft concise GitHub issues, epics, and subissues with conventional titles and keep GitHub Projects boards in sync.
---

Write GitHub issues that are brief, actionable, and easy to scan.

- Use a lowercase conventional title: `<type>/<scope>: <imperative summary>`.
- Prefer `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `build`, or `ci`; choose a short scope such as `auth`, `api`, or `eca`.
- Keep the body to the fewest lines that preserve intent. Do not repeat the title, add background that does not affect implementation, or paste research logs.
- Include only relevant sections: problem/goal, acceptance criteria, constraints or non-goals, and verification.
- Make acceptance criteria observable and use short checklists.
- Create subissues only for independently trackable work. Each subissue must have one outcome, name its parent, avoid duplicating the parent body, and use the same title convention.
- Keep the parent focused on shared outcome and integration criteria; link child issues with GitHub's supported parent/subissue mechanism when available.
- Confirm repository and labels before creating anything. Use `gh issue create` (or `gh__issue_create`) for creation and report URLs. Never create duplicates silently.

## Tools

Prefer the `gh__*` MCP tools when they are available. They are restricted to configured owners, take typed arguments, and return JSON envelopes. Read tools run without approval; write tools prompt each call.

- Read: `gh__issue_list`, `gh__issue_view` (includes `parent`, `subIssues`, `issueType`, `projectItems`), `gh__label_list`, `gh__milestone_list`, `gh__issue_type_list`, `gh__project_list`, `gh__project_view`, `gh__project_field_list`, `gh__project_item_list` (supports Projects filter `query`).
- Write: `gh__issue_create`, `gh__issue_edit`, `gh__issue_close`, `gh__issue_reopen`, `gh__issue_comment`, `gh__project_item_add`, `gh__project_item_edit`.
- An `unauthorized_owner` status means the owner is not configured; report it instead of retrying through the shell. Fall back to the `gh` CLI only when the MCP server is unavailable or an operation is not covered, and never for deletes or transfers unless explicitly requested.

## Epics

- An epic is a parent issue whose body states the goal, scope boundaries, and done criteria; its work lives in subissues, not in a long checklist.
- Mark it with the owner's `Epic` issue type when `gh__issue_type_list` shows one, otherwise with an existing `epic` label. If neither exists, ask before creating a label.
- Size subissues to fit within one iteration. Split anything larger into further subissues rather than nesting deeply.
- Create subissues with `parent` set to the epic number (`gh issue create --parent N`), or attach existing issues with `addSubIssues`/`parent` on `gh__issue_edit`. Verify links through `subIssues` on `gh__issue_view`.

## Project boards

GitHub Projects (v2) operations require the `project` token scope.

- Discover before editing: list projects, then read the project's fields (single-select options and iteration IDs) and current items.
- Add an issue with `gh__project_item_add`, or `projects` on create.
- Set one field per `gh__project_item_edit` call by field name and issue URL, using exactly one of `value` (single-select option name), `text`, `numberValue`, `date`, `iterationId`, or `clear`. The CLI equivalent is `gh project item-edit N --owner OWNER --url ISSUE_URL --field NAME --value OPTION`.
- Use only fields, options, and iterations that the project already defines; ask before changing project configuration.
- Prefer moving work through the board's own Status column over closing issues; close an issue only when the user confirms it is done.

Example issue:

```markdown
Title: feat/auth: add passkey sign-in

Support passkeys alongside password login.

- [ ] Users can register and remove a passkey
- [ ] Sign-in falls back to the existing password flow
- [ ] Authentication tests pass
```

Example epic:

```markdown
Title: feat/auth: passwordless sign-in

Let users sign in without a password while keeping the existing flow.

Done when:
- [ ] All subissues are closed
- [ ] Passkey and password sign-in both work end to end

Out of scope: SSO providers.
```

Example subissue:

```markdown
Title: test/auth: cover passkey fallback

Parent: #123

- [ ] Cover unavailable and rejected passkey flows
- [ ] Existing password tests remain green
```
