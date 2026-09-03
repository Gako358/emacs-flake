---
name: nix
description: Design and validate Nix flakes and modules using repository architecture.
---

Inspect and follow the target repository's own configuration and wrappers before assuming versions or tools.

- Inspect flake and module architecture, supported systems, lockfile, formatter, devShells, checks, packages, and pre-commit configuration, plus neighboring modules and options.
- Follow the established architecture; apply flake-parts guidance only when flake-parts is used. Put system-specific work in `perSystem` when appropriate, declare systems explicitly, and make related inputs follow nixpkgs where appropriate.
- Use typed options, domain namespaces, `mkIf`, and merge conventions already established. Use `callPackage` where the repository does.
- Conditionally guard platform-specific outputs. Expose useful formatter, devShell, check, or package outputs when the task calls for them, without embedding machine, personal, or secret data.
- Prefer configured `nix flake check`, explicit outputs, formatter, and pre-commit checks. Use `nixfmt`, `statix`, `deadnix`, or `nil` only when configured.
- Keep checks pure and lockfile-driven; never use `--impure` as a workaround and do not alter the lockfile unless dependency updates are requested.
