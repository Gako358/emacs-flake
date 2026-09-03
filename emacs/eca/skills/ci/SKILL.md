---
name: ci
description: Align CI changes with the repository's flake, checks, and local validation contract.
---

Inspect and follow the target repository's own configuration and wrappers before assuming versions or tools.

- Inspect the flake and existing workflows and scripts first.
- Prefer the flake as the tool and validation contract: use devShell tools, stable checks or packages, and `nix develop -c ...` when no better explicit output exists. Keep local and CI commands equivalent.
- Use the committed lockfile for routine validation. Do not update locks, install ad hoc host tools, or rely on floating global tools.
- Run `nix flake check --keep-going`; build or enumerate relevant exposed checks and packages. Keep jobs composable and use meaningful matrices only. When using GitHub Actions, pin third-party actions to verified full commit SHAs; set explicit workflow/job `permissions`, starting from `{}` or `contents: read` and adding only required scopes. Grant least privilege on other providers using their equivalent controls.
- Treat caching as an optimization, not a correctness requirement. Make cache keys deterministic from relevant lockfiles, system, and toolchain inputs, and do not let untrusted or forked jobs write trusted caches. Do not embed provider-specific secrets or identities; provider syntax is secondary to the Nix contract.
