# Global agent instructions

These instructions apply to every ECA (Editor Code Assistant) session on this
machine, regardless of the project. They are installed by the `emacs-flake`
home-manager module into `~/.config/eca/AGENTS.md`, which ECA auto-loads as
context for every chat. Per-project `AGENTS.md` files at the project root take
precedence / stack on top of this.

Keep this file short and high-signal — under ~300 lines is a good target.

## Hard rules (do not violate)

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
  verification and review.
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
- Every writable file or module has one owner. Workers must stay strictly within
  assigned ownership boundaries and never expand scope silently.
- Read reality before editing: inspect actual APIs, interfaces, and neighbour
  files. Never fabricate functions, imports, flags, or file paths.
- Stop and report back whenever encountering an absent API, interface conflict,
  missing safe verification check, unexpected ownership overlap, or breaking
  change. Do not guess, mock around it, or make unauthorized architectural decisions.

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
- Take the first option that fully works: skip what nobody asked for, then
  reuse an existing helper or pattern in the codebase, then the standard
  library or platform, then an installed dependency, then the minimum new
  code. Be lazy about the solution, never about the change: still update
  every caller, test, fixture, and config it breaks.
- Bug fix: find every caller of the function you touch before editing and
  fix the root cause once in the shared code, not in one caller.
- Code you move or merge keeps its error handling and validation.
- Never cut for brevity: validation at trust boundaries, error handling
  that prevents data loss, security, accessibility, or anything I asked for.
  (Minimal-change rules adapted from MIT-licensed
  https://github.com/DietrichGebert/ponytail/blob/84740e3d344b69b4a133201fa519eb37a62a2b2a/skills/ponytail/SKILL.md)
- Edit existing files in preference to creating new ones. Never create
  README, CHANGELOG, or other docs unless I ask.
- Don't leave scratch files, backups (`*.bak`, `*.orig`) or one-off scripts
  in the workspace. Use `/tmp` and clean up.

## Verifying your work

- Before saying you're done, check `eca__editor_diagnostics` and resolve
  anything you introduced.
- Full initial verification covers the complete current change set and reports all findings together in one response. Full initial review covers the complete diff and reports all actionable findings together; review follows verification even when checks fail.
- The lead combines verifier, reviewer, and security findings into bounded remediation batches. After each implementation invocation, verifier runs the applicable initial or subsequent checks, followed by reviewer and required security review; subsequent gates cover resolution and regressions. Continue outcome-driven cycles until the latest verifier passes and all required reviews are clear, or a genuine blocker or user decision stops progress.
- Final `summary` follows PASSED verification and CLEAR required reviews.
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

## Resource-heavy commands

- Run dev-shell builds and tests through the `nix__*` MCP tools, never
  through the shell; any agent or subagent may call them:
  - Haskell: `nix__cabal` with `command` `build` or `test`, `targets`
    (e.g. `["all"]`), optional `devShell` (e.g. `haskell`) and `projectDir`
    relative to the root (e.g. `tools/nmkp-cli`). `test` streams test
    details.
  - Scala: `nix__sbt` with `tasks`, including `project/task` and
    `project/Config/task` forms (`server/compile`, `unitTests/test`,
    `containerTests/Test/compile`, `scalafixAll --check`,
    `scalafmtCheckAll`).
  - Flake outputs (including fixed-output hash checks such as
    `sbtDepsCache`): `nix__build` with `attributes` and optional
    `devShell`. It runs a pure `nix build` inside the dev shell, matching
    my direnv workflow; read `specified:`/`got:` hashes from its stderr.
    Do not use `--impure`, and do not ask me to run `nix build`.
  - `root` is the repository or worktree flake directory. Calls on the
    same root queue in order, and heavy calls (`flake_check`, `build`,
    `develop`, `run`, `sbt`, `cabal`) also share a small machine-wide job
    limit across all ECA sessions. Queued calls block until their turn, so
    do not cancel or retry them. On `unauthorized_root`, stop and tell me
    which root to authorize.
  - The `nix__*` tools allow import-from-derivation, so they may evaluate
    and build any dev shell (`ci`, `default`, `haskell`, ...) or output,
    including ones that pull in Haskell packages. Use them for that; the
    Haskell restrictions below do not apply to `nix__*` calls.
  - Never ask me to run a command that a `nix__*` tool covers, and never
    swap the requested dev shell for another one to make a call evaluate.
    If a `nix__*` call fails, report its `status`, `exitCode`, and the
    relevant stderr, fix the cause when it is in scope, and retry.
- Never run other GHC/Haskell toolchain commands (`ghc`, `ghci`, `runghc`,
  `stack`, `haskell-language-server`), `cabal` outside `nix__cabal`, or
  environment reloads (`direnv reload`, `direnv exec`,
  `nix-direnv-reload`) yourself through the shell — not directly and not
  through `nix develop -c`.
- Only when one of those is needed and no `nix__*` tool covers it, stop and
  ask me to run it. Batch them so I run as few as possible, and for each give:
  - the absolute working directory;
  - the environment it must run in (plain shell, inside the direnv/
    `nix develop` shell, or a specific dev shell such as `.#ci`), and
    whether a `direnv reload` must come first;
  - one copy-pasteable fenced `sh` block per step, with real paths,
    targets, and flags filled in — no placeholders or "something like";
  - what output to paste back (full output, exit code, or only errors).
- Then wait for my pasted result before continuing.
- Verification evidence from my pasted output counts; anything I did not
  run stays UNVERIFIED.

## Git safety

- Read-only Git commands may run without confirmation. Before every other Git
  command, ask for command-specific approval.
- The manually selected `version` agent is exempt and follows its own Git safety
  instructions.

## Things to avoid

- Don't run destructive non-Git shell commands (`rm -rf`, DB drops, file
  deletes outside the workspace) without explicit confirmation.
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
