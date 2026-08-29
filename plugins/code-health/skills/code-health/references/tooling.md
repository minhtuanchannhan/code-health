# Code Health Tooling

Use existing project tools before introducing anything new. Do not install tools automatically. If a useful check is unavailable, report the gap and the command that a maintainer can run later.

## Baseline collector

Run from the target repository root after installation:

```bash
./.code-health/framework/scripts/code-health/collect-baseline.sh
```

From the framework source checkout, use `./scripts/code-health/collect-baseline.sh`. The collector records repository metadata, tracked-file and manifest inventories, CI configuration paths, available tool versions, and suggested project checks under `.code-health/runs/`. It does not inspect environment-variable values or run project code.

## Evidence sources

### Repository and change history

Use `git status`, `git diff`, `git log`, and fast code search. Preserve the user's working tree and do not rewrite history during an audit.

### JavaScript and TypeScript

Prefer configured package-manager scripts, ESLint, TypeScript, unit or integration tests, browser tests, and the package manager's audit command.

### Python

Prefer configured pytest, Ruff, mypy, dependency audit, and packaging checks.

### Go, Rust, JVM, Ruby, PHP, and .NET

Use repository wrappers and configured native test, lint, static-analysis, and dependency commands. Do not bypass lockfiles or silently update dependencies.

### Security

Useful existing signals include CodeQL, Semgrep, Trivy, dependency audits, Dependabot, and secret scanners. Confirm reachability, data flow, and existing mitigations before reporting a vulnerability. Security review must stay within the authorized repository and use non-destructive techniques.

### Performance and scalability

Prefer profiles, request timings, benchmarks, database query plans, memory measurements, bundle analysis, and capacity evidence. Do not call code slow because it merely looks inefficient. Use production data only through approved, read-only access.

### Database

Inspect query shapes, indexes, pagination, N+1 behavior, transactions, locks, connection handling, and migration safety. Never mutate production data during analysis.

### Reliability and observability

Inspect timeouts, retry limits, idempotency, failure recovery, transaction boundaries, concurrency, cleanup, error propagation, structured logs, metrics, tracing, and alerts. Never include passwords, tokens, authorization headers, health data, personal data, or secrets in audit output.

### CI and delivery

Check whether required tests, lint, type checks, security checks, builds, and deployment safeguards are present and actually block unsafe changes.

## Execution rules

- Start with the smallest safe check.
- Read project scripts before running them.
- Do not run commands that mutate data, publish artifacts, deploy, or rotate credentials without explicit approval.
- Capture command, exit status, and relevant output.
- Treat a passing scanner as one signal, not proof that a system is safe.
- Treat a failing scanner as a lead until the result is validated.
