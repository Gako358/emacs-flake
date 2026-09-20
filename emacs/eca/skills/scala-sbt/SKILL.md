---
name: scala-sbt
description: Build and verify Scala and sbt changes using repository conventions.
---

Inspect and follow the target repository's own configuration and wrappers before assuming versions or tools.

- Inspect `flake.nix` and its dev shell, wrappers, `build.sbt`, `project/`, modules, Scala version, `.scalafmt.conf`, `.scalafix.conf`, aliases, and test framework.
- Prefer the project's Nix dev shell and wrappers. Run supported `sbtn` tasks through `nix__sbt`, passing the authorized `root`, optional `devShell`, and exact `tasks`; this includes compile, test, testQuick, scalafixAll, scalafmt, scalafmtAll, and scalafmtCheckAll, including module-scoped forms. Do not run these tasks or `nix develop` through the shell. Use `sbt` only as a shell fallback when `sbtn` is unavailable, and report that the MCP operation could not be used.
- Follow Scala 3 fewer-braces syntax only when local configuration does, and preserve strict-warning and import policies.
- Prefer pure, typed transformations. Where local compiler or Scalafix policy supports it, avoid `var`, `null`, `throw`, `return`, `while`, unsafe casts, and partial access.
- If Typelevel is present, use `F[_]`, `Resource`, explicit effects, and compositional FS2. Represent expected failures with `Option`, `Either`, or domain errors; exceptions remain appropriate at integration boundaries.
- Discover the unit, container, and integration test split and its configured framework (use Weaver only when configured); target relevant modules and suites.
- Verify with `nix__sbt` tasks `scalafmtCheckAll`, `scalafixAll --check`, and targeted compile/tests, using repository aliases or wrappers where provided.
