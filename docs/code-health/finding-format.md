# Code Health Finding Format

Every confirmed finding must use this structure. Keep evidence factual and recommendations proportional.

```markdown
## <CATEGORY>-<NNN>: <short title>

- Category: Security | Reliability | Architecture | Maintainability | Performance | Scalability | Testability | Developer Experience
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Probability: 1-5
- Blast radius: 1-5
- Risk score: <calculated value>
- Priority: P0 | P1 | P2 | P3
- Effort: XS | S | M | L | XL

### Location

- `path/to/file.ext:<line>` - primary evidence
- `path/to/related.ext:<line>` - related caller, test, or configuration

### Evidence

Describe exactly what was observed. Include the relevant execution path, configuration, tool output, or runtime result. Distinguish observed facts from inference.

### Impact

Explain the user, security, data, operations, or engineering consequence.

### Trigger

State the conditions required for the issue to occur.

### Root cause

Describe the underlying engineering cause, not only the local symptom.

### Recommendation

Describe the smallest reasonable remediation. Do not provide implementation code unless requested.

### Verification

Describe the exact test, scanner, query plan, benchmark, or runtime observation that would prove remediation.
```

## Rules

- Use stable category prefixes such as `SEC`, `REL`, `ARCH`, `MAIN`, `PERF`, `SCALE`, `TEST`, and `DX`.
- Include line numbers when the evidence is line-specific. Use a symbol or configuration key when line numbers would be unstable.
- Do not paste secrets, tokens, personal data, or large code blocks into a finding.
- Do not duplicate one root cause across several findings unless impacts require different owners or remediations.
- Label an unverified concern as an investigation lead, not as a confirmed finding.
- State when scanner output is unreachable, mitigated, or a false positive.

## Compact report index

Before the full findings, provide a table containing ID, title, category, severity, confidence, priority, effort, and primary location.
