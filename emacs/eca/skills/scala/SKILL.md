---
name: scala
description: Implement Scala application code, tests, and SBT builds idiomatically, including Cats/Cats Effect, Circe, Scalafmt, and Scalafix.
---

Handle Scala application code, tests, SBT build definitions, Scalafmt, Scalafix, Metals-oriented project structure, and migration fixes. Also load the `scala-sbt` skill and use its `nix__sbt` workflow for supported `sbtn` and dev-shell operations.

- Prefer functional, type-directed Scala; avoid mutable state, `null`, `throw`, and `.get` for expected domain failures.
- Where Cats/Cats Effect is present, use its idioms: `IO`, `Resource`, `Ref`, `Deferred`, typeclass instances, and `for`-comprehensions over raw callbacks.
- Keep effectful code at the boundary; keep pure logic in plain functions that return `Either`, `Validated`, or `NonEmptyList` as appropriate.
- For typed domain errors, use MTL-style `Raise`/`Handle` (e.g. `cats.mtl.Raise`/`Handle`) where the project already uses them; otherwise use `EitherT` or `ApplicativeError` consistently with existing code.
- Circe: never use `io.circe.generic.auto._` or `io.circe.generic.semiauto._`. Write any needed `Encoder`, `Decoder`, or `Codec` instances explicitly by hand, scoped to the companion object.
- Prefer total functions; use `Option`/`Either`/`Validated` over partial matching or exceptions for recoverable failures.
- Respect existing Scalafmt and Scalafix configs; do not reformat unrelated lines. Respect existing SBT module layout, dependency style, and test framework.
