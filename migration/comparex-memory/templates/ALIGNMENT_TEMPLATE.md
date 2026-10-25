# ALIGNMENT.md — Comparex memory layer vs. existing build

_Written by Amp in Phase 0. Approved by: ____ on ____._

## 1. Current build summary
- Languages / runtime:
- Package layout and entry points:
- How Comparex runs and where results are stored (files / DB / Snowflake):
- How issue, triage and handoff MD files are created and named:
- How Copilot CLI agents and Amp are invoked:
- Config system:
- DB and Snowflake access code:
- Logging, errors:
- Tests and fixtures:
- Scheduler:
- Dependencies already available:

## 2. Component map
| Guide component | Existing code (path) | Decision: reuse / extend / add | Notes |
| --- | --- | --- | --- |
| Config loading (5) | | | |
| Write guard (7) | | | |
| DB access (6) | | | |
| Compare runs + differences (6.1, 9.3) | | | |
| MD parsing (9.2) | | | |
| Git access (9.4) | | | |
| Signatures (8) | | | |
| Outcomes and playbooks (10) | | | |
| Recall and memory file (11) | | | |
| CLI (11.4) | | | |
| Scheduling (12.1) | | | |
| Snowflake sync (13b, version 2 only) | | | |
| Tests and fixtures (14) | | | |

## 3. Proposed layout

## 4. Proposed changes to existing code (prefer none)
| File | Reason | Exact diff | Risk |
| --- | --- | --- | --- |

## 5. Deviations from the guide
| Guide section | What changes | Why | Invariants in 0.1 still hold? |
| --- | --- | --- | --- |

## 6. Questions for the team

## Version 2 (fill in only when adding Snowflake, prompt V2-0)
- Existing Snowflake access code to reuse:
- How credentials are provided today (never in this file):
- Test schema and production schema:
- Roles that need read / write access:
- Proposed changes to existing code (exact diffs; prefer none):
- Approved by: ____ on ____
