---
name: vue-typescript
description: Implement and verify Vue 3 and TypeScript changes within local frontend conventions.
---

Inspect and follow the target repository's own configuration and wrappers before assuming versions or tools.

- Inspect the flake or dev shell, package-manager lockfile and workspaces, package scripts, `tsconfig`, Vue config, lint/format/test setup, and neighboring code.
- Use defined scripts and the committed package manager; do not use floating global tools or speculative installs.
- Prefer Vue 3 Composition API with `<script setup lang="ts">`, typed props and emits, strict TypeScript, discriminated unions, and type-only imports when local configuration supports them.
- Keep components focused and put reusable logic in existing composable, store, API, or query layers. Use Pinia for client state, Vue Query for server state, and Zod or Vee Validate for complex forms only when present.
- Model explicit loading, empty, success, and error states. Preserve generated-client boundaries and local style.
- Verify applicable package scripts in order: format check, lint, typecheck, unit tests, build, and relevant E2E tests. Use ESLint, Prettier, Vitest, Vue Test Utils, or Playwright only when configured.
