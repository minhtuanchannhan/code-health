# Repository Agent Instructions

## Purpose

This repository uses coding agents for implementation, review, maintenance, and evidence-backed code-health analysis.

The framework can be used from its source checkout or installed under `.code-health/framework/`. Resolve the framework root before reading framework documents: use `.code-health/framework/` when it contains this file, otherwise use the current repository root. Paths below are relative to that resolved framework root unless stated otherwise.

Before working, read the relevant guidance:

- `docs/code-health/README.md`
- `docs/code-health/scoring.md`
- `docs/code-health/finding-format.md`
- `docs/code-health/tooling.md`

Also read architecture, domain, and local instruction files that govern the code in scope.

## Priorities

Prioritize security, correctness, reliability, and data integrity before maintainability, performance, scalability, or developer convenience. Never trade correctness or security for a simpler diff.

## Working rules

Before changing code:

1. Reproduce or otherwise establish the current behavior.
2. Trace callers, downstream consumers, and external contracts.
3. Search for existing patterns and relevant tests.
4. Identify authentication, authorization, sensitive-data, persistence, and public-API boundaries.

During implementation:

- Make the smallest coherent change that fixes the verified cause.
- Prefer existing patterns, explicit error handling, deterministic behavior, and testable interfaces.
- Preserve backward compatibility unless a breaking change is explicitly approved.
- Avoid unrelated refactors, speculative abstractions, duplicated business logic, silent failures, and unnecessary dependencies.

After implementation, run the smallest relevant checks first, then the broader applicable test, lint, type-check, build, security, or benchmark commands. Never claim a check passed unless it ran successfully. Report checks that could not run.

## Code-health audits

An audit is read-only unless the user explicitly requests implementation. Do not modify production code while discovering or reporting findings.

Use this order:

1. Define scope: changed code, component, repository, or deep audit.
2. Build a repository map before specialist analysis.
3. Review security, reliability, architecture, maintainability, performance, scalability, testing, and developer experience as applicable.
4. Write every finding using `docs/code-health/finding-format.md`.
5. Consolidate duplicates and distinguish root causes from symptoms.
6. Prioritize using `docs/code-health/scoring.md`.
7. List unknowns, assumptions, and checks that were not available.

Specialist reviews may run sequentially or in parallel when the runtime supports it and the user has authorized delegation. Discovery must complete first. Specialist output is advisory and must be consolidated before presentation.

## Safety

Never expose or commit credentials, print secret values, weaken access controls for convenience, disable tests to make checks pass, suppress security warnings without evidence, mutate production data during analysis, or run destructive infrastructure operations without explicit approval.

## Definition of done

Work is complete only when the requested outcome is present, relevant validation has passed, the diff contains no unrelated changes, security and compatibility implications were considered, and limitations are clearly reported.
