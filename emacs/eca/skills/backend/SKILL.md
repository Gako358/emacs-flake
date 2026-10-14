---
name: backend
description: Implement non-Scala backend services, APIs, persistence, CLIs, Nix modules, infrastructure, and integration boundaries.
---

Handle non-Scala APIs, services, persistence, CLIs, Nix modules, server-side code, and integration boundaries. Combine with the `scala` or `java` skill when the backend is written in those languages, and with the `nix` skill for Nix work.

- Prefer tools exposed by the project's `flake.nix`/dev shell.
- Keep changes minimal, type-safe where applicable, and consistent with existing architecture.
- Treat API shapes, schemas, and migrations as shared contracts: change them only as the task packet specifies and preserve backwards compatibility unless told otherwise.
