---
name: implementation-planning
description: Structure complex features or refactors into bounded, observable, parallelizable workstreams.
---

Decompose engineering initiatives into concrete, independently verifiable workstreams before execution.

- Ground plans in existing architecture: inspect neighboring modules, existing types, and entry points before designing changes.
- Consider materially different designs only when real, unresolved trade-offs exist; otherwise proceed with the simplest idiomatic path. Use expand-migrate-contract sequencing only when live compatibility migrations require it.
- Never let workers invent APIs or silently resolve architectural ambiguities. Resolve blocking scope questions with a single focused question through the lead agent before proceeding.
- Define executable bounded workstreams structured as small vertical tracer slices with end-to-end coverage, rather than horizontal slicing (e.g. avoid implementing all tests first across modules before writing any code).
- Specify exact shared seam and interface contracts up front: public types, function signatures, invariants, error semantics, and backward compatibility bounds.
- Provide observable examples with expected inputs/outputs, explicit failure/regression scenarios, and concrete verification commands with working directories and expected outcomes.
- Keep workstream packets strictly bounded. Every workstream must define all nine standard fields:
  1. Workstream ID
  2. Specialist
  3. Goal
  4. Owned files/modules
  5. Dependencies
  6. Shared interfaces
  7. Parallel group
  8. Integration order
  9. Targeted validation
- Specify explicit stop criteria, non-goals, and decisions made versus remaining open questions.

---
Inspired by Matt Pocock’s MIT-licensed skills (2026):
- https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-tickets/SKILL.md
- https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/codebase-design/SKILL.md
- https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/codebase-design/DESIGN-IT-TWICE.md
- https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grilling/SKILL.md
