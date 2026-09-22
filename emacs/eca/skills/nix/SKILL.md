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
- For supported operations, use the typed MCP tools: `nix__flake_metadata` and `nix__flake_show` for metadata/show, `nix__flake_check` for checks, `nix__eval` for one specific attribute, `nix__build` for specific attributes, `nix__develop` to verify a default or named dev shell, and `nix__run` for allowlisted batch Emacs validation through a flake app. Pass the authorized `root` and exact operation-specific schema fields, and record their JSON text result as evidence.
- Run every supported `nix run` operation through `nix__run` and every supported `nix develop` operation through `nix__develop` or the dedicated command tool such as `nix__sbt`; do not invoke `nix develop` through the shell. Use shell only for other unsupported operations or MCP debugging. Never retry a policy-rejected expression or path through shell, and never bypass a rejected run argument through shell. Preserve `--no-write-lock-file` safety for shell fallback and require recorded MCP or literal shell evidence before claiming success.
- Keep checks pure and lockfile-driven by default. Use `--impure` only when the check genuinely depends on local paths, environment state, or another explicitly impure input, and state why; do not use it to bypass a reproducibility failure. Do not alter the lockfile unless dependency updates are requested.
