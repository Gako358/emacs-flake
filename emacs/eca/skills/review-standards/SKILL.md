---
name: review-standards
description: Review conventions learned from engineers' pull request comments, per repository; load when reviewing code in a listed repository.
---

Apply the section of the repository under review. Entries are conventions the team has asked for repeatedly, not proof of a defect: a violation needs a concrete case to be more than a `should`. Entries are maintained, committed, and pushed by the `version` agent.

Entry format, under one `### <owner>/<repo>` heading per repository:

```markdown
### acme/app

Mined through: #123

- Prefer `Option` over `null` in Scala domain models (seen 3, last #118)
```

## Repositories

### HNIKT-Tjenesteutvikling-Systemutvikling/kvalreg-nmkp

Mined through: #2501

- Reuse existing definitions (codegen schemas, shared constants, composables) instead of duplicating them in Scala and TypeScript code (seen 2, last #2494)
