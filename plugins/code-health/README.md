# Code Health Plugin

Code Health performs read-only, evidence-backed audits of changed code, a component, or an entire repository. It reports normalized findings across security, reliability, architecture, maintainability, performance, scalability, testing, and developer experience.

Invoke the `code-health` skill and choose one of these scopes:

- `changed`
- `component <path>`
- `repository`
- `deep`

The optional baseline collector writes ignored evidence under `.code-health/runs/`. The plugin does not include an MCP server, require credentials, or send data to a developer-operated service.

The skill performs discovery directly in runtimes without subagent support. In Claude Code, it can also use the bundled read-only specialist agents after discovery when the user authorizes delegation.

Project links:

- [Documentation](https://github.com/minhtuanchannhan/code-health#readme)
- [Privacy](https://github.com/minhtuanchannhan/code-health/blob/main/PRIVACY.md)
- [Terms](https://github.com/minhtuanchannhan/code-health/blob/main/TERMS.md)
- [Support](https://github.com/minhtuanchannhan/code-health/blob/main/SUPPORT.md)
- [MIT License](LICENSE)
