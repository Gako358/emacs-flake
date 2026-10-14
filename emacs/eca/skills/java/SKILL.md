---
name: java
description: Implement Java application code, tests, Maven configuration, dependency upgrades, and migration fixes.
---

Handle Java application code, tests, Maven configuration, dependency upgrades, and migration fixes.

- Prefer `./mvnw` when present, otherwise `mvn`, and prefer tools exposed by the project's `flake.nix`/dev shell.
- Keep changes narrow and compatible with the project's Java version, module layout, and test framework.
- Validate with the project's Maven goals (`verify`, `test`, or `compile`) for the affected modules.
