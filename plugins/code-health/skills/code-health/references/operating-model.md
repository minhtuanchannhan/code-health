# Code Health Operating Model

## Goal

The code-health process identifies engineering risk and improvement opportunities while preserving correct existing behavior. It is an audit and remediation workflow, not a generic refactoring exercise.

The assessed dimensions are:

- Security
- Reliability
- Architecture
- Maintainability
- Performance
- Scalability
- Testability
- Developer experience

## Principles

### Evidence over opinion

Every finding must reference concrete evidence such as a file and symbol, execution path, configuration, dependency, test, scanner result, query plan, benchmark, or observed runtime behavior. Style preference alone is not a finding.

### Risk over cleanliness

Prioritize risks that can cause unauthorized access, sensitive-data exposure, incorrect results, data loss, outages, severe latency, scaling failure, or high regression risk before cosmetic cleanup.

### Causes over symptoms

Trace a local symptom to its engineering cause. For example, duplicated authorization checks are more useful to report than the size of one handler.

### Existing tools first

Use the repository's configured checks before proposing new dependencies. Scanner output is a lead, not proof. Validate reachability and impact before creating a finding.

### Architecture follows evidence

Do not recommend microservices, queues, caches, new databases, or orchestration platforms unless an observed constraint requires them.

## Scope modes

- **Changed:** Review the working tree or a supplied diff.
- **Component:** Review a named service, module, directory, or user flow.
- **Repository:** Review the whole repository at practical depth.
- **Deep:** Add available dependency, security, database, CI, observability, and performance evidence to a repository review.

Scope limits must be stated in the final report.

## Phases

### 1. Discovery

Map languages, frameworks, entry points, services, persistence, integrations, trust boundaries, infrastructure, CI, tests, observability, and critical business flows. Record unknowns instead of guessing.

### 2. Specialist review

Choose specialists based on the repository map. Architecture and performance jointly cover scalability. Maintainability and testing jointly cover developer experience.

### 3. Consolidation

Merge duplicates, group findings that share a cause, reject unsupported claims, and separate confirmed findings from investigation leads.

### 4. Prioritization

Apply `scoring.md`. Risk determines priority. Effort informs sequencing but does not reduce the stated risk.

### 5. Implementation

Implementation begins only after findings are selected. Prefer one concern per change and add or update a test that fails for the original issue when practical.

### 6. Verification

Independently reproduce the original evidence, inspect the change, and run applicable tests, lint, type checks, builds, scanners, and benchmarks. A changed file is not proof that a finding is fixed.

## Required audit output

1. Scope and repository summary
2. Executive risk summary
3. Findings ordered by priority
4. Cross-cutting causes
5. Positive controls worth preserving
6. Unknowns and untested assumptions
7. Checks run, with results
8. Recommended next actions

## Non-goals

The process does not aim to maximize code changes, rewrite working systems, enforce personal preferences, reach arbitrary coverage targets, or introduce technology without measurable benefit.
