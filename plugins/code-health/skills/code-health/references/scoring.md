# Code Health Scoring

Scoring makes prioritization consistent. It does not replace engineering judgment, and it must never hide a Critical or High finding.

## Dimension weights

| Dimension            | Weight |
| -------------------- | -----: |
| Security             |    20% |
| Reliability          |    15% |
| Architecture         |    15% |
| Maintainability      |    15% |
| Performance          |    10% |
| Scalability          |    10% |
| Testability          |    10% |
| Developer experience |     5% |

Weights are for an optional repository health summary. Finding priority is calculated separately.

## Severity

| Severity | Value | Meaning                                                                                      |
| -------- | ----: | -------------------------------------------------------------------------------------------- |
| Critical |     4 | Plausible security compromise, irreversible data corruption, or widespread production outage |
| High     |     3 | Major user, financial, reliability, access-control, or performance impact                    |
| Medium   |     2 | Localized failure, scaling constraint, difficult change, or elevated regression risk         |
| Low      |     1 | Limited-impact maintainability, readability, optimization, or developer-experience issue     |

## Risk factors

Score probability and blast radius from 1 to 5:

- **Probability:** 1 requires exceptional conditions; 3 is realistic; 5 is present, frequent, or directly reproducible.
- **Blast radius:** 1 affects an isolated path; 3 affects a service or meaningful user group; 5 affects security boundaries, core data, or most users.

Use these confidence multipliers:

| Confidence | Multiplier | Evidence                                                        |
| ---------- | ---------: | --------------------------------------------------------------- |
| High       |       1.00 | Directly observed, reachable, or reproduced                     |
| Medium     |       0.75 | Strong static evidence, but runtime confirmation is unavailable |
| Low        |       0.50 | Plausible lead that still requires investigation                |

## Priority score

```text
risk score = severity value * probability * blast radius * confidence multiplier
```

The maximum is 100.

| Priority | Default score | Expected response       |
| -------- | ------------: | ----------------------- |
| P0       |        80-100 | Investigate immediately |
| P1       |      45-79.99 | Prioritize soon         |
| P2       |      20-44.99 | Plan remediation        |
| P3       |      Below 20 | Fix opportunistically   |

A demonstrated Critical finding with High confidence may be raised to P0 even when its numeric score is lower. Document any override. Low-confidence findings should normally remain investigation leads rather than implementation tasks.

## Effort

| Estimate | Typical size                   |
| -------- | ------------------------------ |
| XS       | Less than 2 hours              |
| S        | Less than 1 day                |
| M        | 1-3 days                       |
| L        | 3-5 days                       |
| XL       | Multi-stage architectural work |

Effort does not reduce severity or priority. Use it only to plan delivery among similarly risky findings.

## Optional repository health score

Only produce a health score when every dimension received meaningful review. Rate each dimension from 0 to 100 using explicit evidence, then calculate the weighted average above. Use these anchors:

- 90-100: Strong controls with no material verified gap
- 80-89: Good, with limited and contained gaps
- 70-79: Needs attention
- 60-69: Significant debt or control weakness
- Below 60: High engineering risk

Always display Critical and High findings beside the aggregate. Do not increase a score because a problem was documented. Only verified remediation changes the score.
