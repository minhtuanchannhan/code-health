---
name: code-health
description: Use when the user asks for a code-health audit, repository risk assessment, changed-code review, or evidence-backed review of security, reliability, architecture, maintainability, performance, scalability, testing, or developer experience.
argument-hint: "[changed | component <path> | repository | deep]"
---

Run a code-health audit. This skill reports findings and does not implement them.

## 1. Resolve scope

Interpret `$ARGUMENTS` as one of:

- `changed`: current working-tree diff, or the comparison supplied by the user
- `component <path>`: the named path and its callers, consumers, tests, and contracts
- `repository`: the whole repository at practical depth
- `deep`: repository scope plus available dependency, security, database, CI, observability, and performance evidence

Default to `repository` when no argument is supplied. Reject a component path outside the repository. State the resolved scope and exclusions.

## 2. Load the contract

Read the target repository's `AGENTS.md` and any closer instructions. Then read these bundled references, resolving paths relative to this `SKILL.md`:

- [Operating model](references/operating-model.md)
- [Scoring](references/scoring.md)
- [Finding format](references/finding-format.md)
- [Tooling](references/tooling.md)

Obey closer repository instructions when present.

## 3. Collect and investigate

Run the bundled `scripts/collect-baseline.sh` when safe and relevant, resolving it relative to this `SKILL.md`. Do not install missing tools.

Complete discovery before specialist analysis. When the runtime exposes the bundled `code-health-investigator` agent and the user has authorized delegation, use it first and pass its repository map to later specialists. Otherwise, perform discovery directly in the current thread. Delegation is an optimization, not a prerequisite.

## 4. Select specialists

Review only relevant dimensions. When the runtime exposes bundled specialists and delegation is authorized, invoke the matching read-only agents:

- `security`
- `performance`
- `architecture`
- `maintainability`
- `reliability`
- `testing`

For repository and deep scopes, cover all dimensions unless discovery establishes that one is not applicable. Specialists may run concurrently after discovery. Give each specialist the repository map, exact scope, and any applicable baseline evidence. Without bundled specialists, perform the same reviews directly and sequentially.

Keep all audit work read-only. Do not ask `verifier` to review unimplemented recommendations.

## 5. Consolidate

Validate every proposed finding against the required format. Reject unsupported claims. Merge duplicates and group symptoms under their root cause. Recalculate risk scores consistently and document priority overrides.

Keep unverified concerns in an investigation-leads section. Do not present them as confirmed defects.

## 6. Report

Return:

1. Scope and repository summary
2. Executive risk summary
3. Compact finding index ordered by priority, risk score, then confidence
4. Full normalized findings
5. Cross-cutting root causes
6. Positive controls worth preserving
7. Investigation leads
8. Unknowns, exclusions, and checks that could not run
9. Checks run with results
10. Recommended next actions

Only provide an aggregate health score for a complete repository or deep audit where every dimension received meaningful evidence. Keep Critical and High findings visible beside any score.

End by asking the user to select findings before implementation. After selected fixes are implemented, use `verifier` in a separate verification pass.
