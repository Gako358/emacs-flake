---
name: frontend
description: Implement frontend work in TypeScript, Vue, CSS, UI state, accessibility, and browser-facing code.
---

Handle UI, TypeScript, Vue, CSS, accessibility, client-side state, forms, and browser-facing integration. Also load the `vue-typescript` skill for Vue or TypeScript work.

- Keep changes narrow and idiomatic for the project. Prefer existing components, composables, styles, and patterns over new abstractions.
- Run available and relevant local checks using the project package manager and flake/dev shell tools: prefer defined `typecheck`/`type-check` or equivalent `tsc`/`vue-tsc` scripts, plus `lint`, `test`, `build`, or `check` scripts when defined.
- Do not assume npm or global tool availability. Report every check run and its result; note explicitly when relevant checks were unavailable or skipped.
