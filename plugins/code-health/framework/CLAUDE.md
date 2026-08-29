# Claude Code Instructions

Read the target repository's `AGENTS.md` first. Then read `.code-health/framework/AGENTS.md` when the framework is installed, or the local `AGENTS.md` when working in the framework source checkout.

## Code-health workflow

Run `/code-health` for an evidence-backed audit. The supported scopes are:

- `changed`
- `component <path>`
- `repository`
- `deep`

The specialist definitions are in `.claude/agents/`. Use `code-health-investigator` first, then use only the specialists relevant to the discovered repository and requested scope. Keep specialist work read-only. Consolidate their output before reporting it.

Do not implement audit findings unless the user explicitly selects findings for implementation. After implementation, use `verifier` to confirm that the original evidence no longer reproduces and that relevant checks pass.

Repository-specific behavior and business rules take precedence over generic advice. Prefer evidence from source code, tests, configuration, safe runtime behavior, and existing documentation. Do not infer architectural problems from naming or folder structure alone.
