---
name: implementation-planning
description: Structure complex features or refactors into bounded, observable, parallelizable workstreams.
---

Decompose engineering initiatives into concrete, independently verifiable workstreams before execution.

- Return a populated JSON-compatible register for requirements, workstreams, tasks, evidence, and gates; prose alone is not a plan. Stable AC, workstream, and task IDs must flow into assignments, reports, verifier evidence, and the final summary.
- Ground plans in existing architecture: inspect neighboring modules, existing types, and entry points before designing changes.
- Consider materially different designs only when real, unresolved trade-offs exist; otherwise proceed with the simplest idiomatic path. Use expand-migrate-contract sequencing only when live compatibility migrations require it.
- Never let workers invent APIs or silently resolve architectural ambiguities. Resolve blocking scope questions with a single focused question through the lead agent before proceeding.
- Require researcher handoffs to cover request, constraints, paths/ranges, current data flow, APIs/interfaces, patterns, checks/dev shell, affected areas, risks/blockers, and unverified assumptions.
- Require every gate assignment to include `Workflow intent: <plan|implementation|integration|remediation|verification|review|security|summary>`, stable IDs, ownership metadata, and evidence expectations. Invocation markers prove invocation only; returned reports establish PASSED/FAILED/UNVERIFIED or CLEAR/FINDINGS/UNVERIFIED outcomes.
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
