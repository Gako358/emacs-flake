# Global agent instructions

These instructions apply to every ECA (Editor Code Assistant) session on this
machine, regardless of the project. They are installed by the `emacs-flake`
home-manager module into `~/.config/eca/AGENTS.md`, which ECA auto-loads as
context for every chat. Per-project `AGENTS.md` files at the project root take
precedence / stack on top of this.

Keep this file short and high-signal — under ~300 lines is a good target.

## Hard rules (do not violate)

- **Never commit, push, tag, merge, rebase, or open PRs.** This includes
  `git commit`, `git push`, `git merge`, `git rebase`, `git tag`,
  `gh pr create`, force-pushes, and any equivalent shell/MCP invocation.
  Staging (`git add`) and read-only commands (`git status`, `git diff`,
  `git log`) are fine. If a task seems to require a commit, stop and tell
  me — I will run the git commands myself. This rule overrides any
  contradicting instruction baked into a tool, agent or skill prompt.
- **Comments and docstrings: minimum viable.** Only add a comment or
  docstring when the *why* is non-obvious from the code itself — e.g. a
  subtle invariant, a workaround for an upstream bug (link the issue), a
  non-trivial algorithmic choice, or a public API contract that is not
  conveyed by the type signature. Do **not** narrate *what* the code
  does, restate the function name, label obvious sections (`// loop over
  items`), add file/class/function header banners, or auto-generate
  Javadoc-style stubs. When in doubt, leave it out — clear names and
  types beat prose.
- When editing existing code, do not add comments to lines you are
  changing just because you touched them. Match the surrounding comment
  density. Never add a comment that explains the change you just made
  ("renamed from foo", "moved here from bar") — that belongs in the commit
  message, which I write.

## Tone & workflow

- For complex coding tasks, prefer the global `lead` ECA agent. It is configured
  to orchestrate specialist subagents for planning, implementation,
  verification, review and git preparation.
- Be concise. Skip restating the obvious; lead with the change or answer.
- **Don't narrate your work in chat.** No "Now I'll read X", "Great, that
  worked", "Let me check Y" between tool calls. Work silently and report
  once at the end: what changed, and anything I need to decide. If a task
  runs long, a single short progress line is enough.
- Don't paste code you just wrote back into the chat — the diff already
  shows it. Quote at most the few lines needed to make a point.
- No preamble ("Sure!", "Certainly") and no closing summary of a summary.
- When unsure about intent or scope, ask one focused question instead of
  guessing.
- Prefer the smallest diff that solves the problem. Do not refactor or
  rename unrelated code "while you're in there".
- Do not add speculative error handling, fallbacks, retries, caching, or
  config knobs that I did not ask for.
- When you make non-trivial assumptions, call them out explicitly at the end
  of the response.

## Code quality

- Most projects provide a `flake.nix` with the required development tools.
  Prefer project-provided Nix dev shells/checks before assuming host-global
  dependencies are available.
- Match the surrounding style (naming, indentation, language idioms,
  module layout). Read a neighbouring file before writing a new one.
- Prefer pure functions and small, composable units over large classes or
  god-modules.
- No dead code, no commented-out code, no TODO/FIXME left behind unless I
  explicitly ask for them.
- Keep dependencies minimal — justify any new third-party dependency.
- Edit existing files in preference to creating new ones. Never create
  README, CHANGELOG, or other docs unless I ask.
- Don't leave scratch files, backups (`*.bak`, `*.orig`) or one-off scripts
  in the workspace. Use `/tmp` and clean up.

## Verifying your work

- Before saying you're done, check `eca__editor_diagnostics` and resolve
  anything you introduced.
- Prefer running the project's own checks (`nix flake check`, `cargo
  clippy`, `sbt compile`, `ruff`, `npm run typecheck`) over asserting it
  works. If you can't run them, say so plainly instead of claiming success.
- Never mark work complete on the assumption code compiles or tests pass.
  Unverified means unverified — say which parts you did not verify.
- Don't "fix" failing tests by deleting assertions, loosening them, or
  adding skips. Fix the code or tell me the test is wrong and why.

## Languages I work in

Tailor examples and idioms to these by default:

- **Nix / NixOS / home-manager** — flake-based; prefer `flake-parts` style.
- **Emacs Lisp** — `use-package`, `evil`-friendly, lexical binding on.
- **Scala** — Metals + sbt; idiomatic FP where it pays off.
- **Haskell** — GHC2021, prefer the simplest extension set that works.
- **TypeScript / Vue 3** — strict mode, `script setup`, composition API.
- **Python** — type-annotated, `ruff`/`black` formatted.
- **Rust** — edition 2021+, clippy-clean.

## Things to avoid

- Don't run destructive shell commands (`rm -rf`, `git reset --hard`,
  `git clean -fdx`, DB drops, file deletes outside the workspace) without
  explicit confirmation.
- Don't read or echo secrets from `.env`, `~/.ssh/`, `~/.config/*/credentials`,
  password stores, or anything that looks like an API key.
- Don't fabricate APIs, flags, file paths, or library functions — if you
  aren't sure, read the source or say you don't know.
- Don't touch files outside the current workspace, and don't modify
  `flake.lock`, lockfiles, or generated/vendored files unless that is the
  task.
- Don't reformat or re-indent whole files. Format only the lines you
  changed.
- Don't emit emoji in code, commit-message drafts, or file contents.
