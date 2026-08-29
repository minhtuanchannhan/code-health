# Code Health

A dependency-free, evidence-first framework for auditing a codebase with Codex or Claude Code. It separates repository discovery, specialist review, prioritization, implementation, and verification so audits do not turn into uncontrolled refactors.

## What it covers

The framework reviews security, reliability, architecture, maintainability, performance, scalability, testability, and developer experience. Every reported finding must point to concrete repository or runtime evidence and include a verification plan.

## Install from a marketplace

After this repository is public on GitHub, Claude Code users can add it as a marketplace and install the plugin:

```text
/plugin marketplace add minhtuanchannhan/code-health
/plugin install code-health@code-health
```

Codex users can install the same package from its Git marketplace:

```bash
codex plugin marketplace add minhtuanchannhan/code-health --ref master
codex plugin add code-health@code-health
```

Start a new Claude Code or Codex conversation after installation so the new skill is discovered.

Workspace administrators can also import this GitHub repository. It includes both supported catalogs:

- `.claude-plugin/marketplace.json` for Claude-compatible imports
- `.agents/plugins/marketplace.json` for Codex and ChatGPT workspace imports

## Install into a repository

The direct installer is useful when the framework instructions and audit tooling should be committed with a target repository. Run it with the root of that Git repository:

```bash
./install.sh /path/to/target-repository
```

The installer puts the canonical framework under `.code-health/framework/`, adds managed code-health sections to the target's existing `AGENTS.md`, `CLAUDE.md`, and `.gitignore`, and installs the project skill and Claude specialist agents under `.claude/`. Repository-owned content is preserved. Installation stops before writing anything when a `.claude` file would be overwritten.

Running the installer again upgrades installer-managed files without duplicating the managed sections. Generated audit evidence remains under `.code-health/runs/`.

The installer adds one audit executable, a safe baseline collector:

```bash
./.code-health/framework/scripts/code-health/collect-baseline.sh
```

When working directly in this framework repository, use `./scripts/code-health/collect-baseline.sh` instead. The collector writes ignored output under `.code-health/runs/`. It does not install tools, read environment-variable values, run application code, or modify source files.

## Use with Codex

Invoke the installed `code-health` skill, or open Codex at an installer-managed target repository. A useful starting request is:

```text
Run a repository code-health audit. Follow AGENTS.md and the code-health docs.
Investigate first, report evidence-backed findings, and do not modify production code.
```

For a narrower review, name the changed files, component, or risk area. Ask for implementation only after selecting findings.

## Use with Claude Code

Open Claude Code at the target repository root and run the installed skill:

```text
/code-health repository
```

Other supported scopes are `changed`, `component <path>`, and `deep`. The skill always runs repository discovery first. In Claude Code, the bundled specialist agents in `.claude/agents/` can then be used when the user authorizes delegation.

## Workflow

1. Collect a safe baseline and map the repository.
2. Review relevant health dimensions.
3. Consolidate duplicate or causal findings.
4. Score risk and report unknowns.
5. Implement only findings selected by a human.
6. Verify the fix independently against the original evidence.

See [docs/code-health/README.md](docs/code-health/README.md) for the full operating model.

## Safety and data handling

Code Health is a skills-only, read-only audit plugin. It has no MCP server, remote service, authentication, telemetry, or developer-operated data collection. The optional baseline collector writes repository metadata under `.code-health/runs/`; it does not read environment-variable values, credentials, or unrelated files. The host product still processes files and prompts under its own terms and workspace controls.

See [PRIVACY.md](PRIVACY.md), [TERMS.md](TERMS.md), and [SUPPORT.md](SUPPORT.md).

## Development and release checks

Run the complete local validation before committing a release:

```bash
bash -n install.sh scripts/code-health/collect-baseline.sh tests/*.sh
./tests/install-test.sh
./tests/release-test.sh
```

When ShellCheck is installed, also run:

```bash
shellcheck install.sh scripts/code-health/collect-baseline.sh tests/*.sh
```

`tests/release-test.sh` validates both catalogs and manifests, legal and listing collateral, the transparent logo, portable plugin execution, source-package consistency, and the Claude package with strict validation when the `claude` CLI is available. GitHub Actions runs the same checks with ShellCheck.

For a release:

1. Update the semantic version in both plugin manifests and the Claude marketplace entry.
2. Update `plugins/code-health/submission/release-notes.md` and rerun all checks.
3. Commit, push `main`, and create the matching Git tag or GitHub release.
4. Test a clean install from `minhtuanchannhan/code-health`, not from the working tree.
5. For Claude Code, the public GitHub marketplace is then installable with the commands above.
6. For Codex and ChatGPT, a workspace admin can import the GitHub marketplace. Publication to OpenAI's universal public Plugin Directory is a separate OpenAI product review or publishing action and is not performed by a Git push.

The OpenAI listing copy, release notes, and five positive plus three negative review cases are in `plugins/code-health/submission/`.

## License

[MIT](LICENSE)
