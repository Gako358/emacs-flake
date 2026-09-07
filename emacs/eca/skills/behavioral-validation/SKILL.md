---
name: behavioral-validation
description: Drive bug fixes and features with reproducible symptoms and observable behavioral verification.
---

Validate software changes through observable behavior and deterministic verification rather than internal assumptions.

- For defect remediation, produce a deterministic reproduction of the reported symptom before applying hypothesis-driven fixes whenever feasible.
- If no deterministic reproduction or verification suite exists, report blockers and validation limits to the lead agent immediately rather than fabricating artificial failing tests.
- Verify through observable public behavior: test at public API boundaries, system interfaces, and user-facing contracts rather than private implementation details or unnecessary mock seams.
- Execute short vertical red-green loops: verify reproduction failure against baseline, implement the minimal fix, and verify resolution alongside regression checks.
- Assert independent expected values; avoid tautological assertions that mirror implementation code.
- Prefer existing project validation tools and dev shells first. Do not add arbitrary dependencies, install ad hoc host packages, or bypass established workflows.
- Do not weaken tests to pass; never fix failing checks by deleting assertions, loosening thresholds, or adding skips. Fix the implementation or report why the test is wrong to the lead without architecture-based authorization.
- Tailor verification to change type: apply behavioral testing to functional logic, while applying linting, formatting, syntax, or documentation checks to configuration and docs without forcing artificial TDD.
- Report verification results objectively: record concrete commands, working directories, exit statuses, and outputs, clearly separating executed results from unverified areas.
- Respect single-pass consolidated remediation: workers never spawn nested agents, execute git commits, or exceed safety boundaries.

---
Inspired by Matt Pocock’s MIT-licensed skills (2026):
- https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/tdd/SKILL.md
- https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/diagnosing-bugs/SKILL.md
