# LIQ Migration: Actions and open questions

_Last updated: 2026-10-18._

## Open questions (need the project lead or team to answer)
| # | Question | Why it matters | Owner | Priority |
|---|---|---|---|---|
| Q1 | After a group switches, does **legacy TDM_CDM keep processing** every business date? | Rollback catch-up depends on it. If it doesn't, the switch can only be fixed forward. | Project lead | **High** |
| Q2 | Which **tier-1 tables does each tier-2 process read**? | This defines the switch groups (D-05). | Project lead / Liquidity team | **High** |
| Q3 | Can **DMVA** delete and insert atomically per business date, truncate and reload, and be retargeted per table? | The daily load after the switch depends on it. | DMVA owner | **High** |
| Q4 | Do the **SnowIn tables have the identity property**, indexes and constraints identical to the originals? | The rename and the identity continuity depend on it. | DBA | High |
| Q5 | **Rollback window** per group, and who is the named decision owner? | Rollback governance | SteerCo | High |
| Q6 | How will **UAT be compared with production**: one tool reading both, or production numbers copied into UAT? | Interim test evidence | Recon owner | Medium |
| Q7 | How far back can **Snowflake reprocess** a past business date? | Reruns after the switch | Snowflake team | Medium |
| Q8 | What is the **fourth SnowIn schema**? | Completeness | Project lead | Low |
| Q9 | Tolerances per measure (counts exact, amounts within what?) | Gate criteria | Business / SteerCo | Medium |
| Q10 | Does anyone else use the **CDM alias, the LIQ procedures or the legacy tables**? | Safe retirement at close-out | Platform team | Medium (before close-out) |

## Next actions (proposed)
| # | Action | Phase | Owner |
|---|---|---|---|
| A1 | Answer Q1 to Q4 | Readiness | Project lead / team |
| A2 | Build the tier-2 to tier-1 mapping and agree the switch groups and their order (Deposits first is suggested) | Readiness | Liquidity team |
| A3 | Structure-parity script: compare columns, identity, indexes, constraints and collation for each SnowIn table against the original | Readiness | DBA |
| A4 | Dependency and grants inventory for each tier-1 table (`sys.sql_expression_dependencies`, triggers, schema-bound views, grants) | Readiness | DBA |
| A5 | Prove DMVA's delete-and-insert and truncate-and-reload behaviour, and its retargeting, in UAT | Readiness | DMVA owner |
| A6 | Write the per-table cutover and rollback runbook (the script is on the master page) and the Control-M change set | Readiness | Project team |
| A7 | Automate the UAT-against-production comparison at tier-1, tier-2 output and report level | UAT | Recon owner |
| A8 | Run the UAT switch for the first group, then compare daily through a month-end and a quarter-end | UAT | Project team |
| A9 | Rehearse the rollback in UAT, including legacy catch-up of several live dates, and time it | UAT | Project team |
| A10 | Agree the gate numbers, tolerances, rollback window and decision owner at SteerCo | Governance | Project lead |
| A11 | Optional deliverable: an Excel test tracker and a cutover runbook document | Any | Agent, if asked |

## Done (deliverables so far)
- Research on how others went live (`liq-golive-research.html`), plus a LinkedIn reading list. LinkedIn itself can't be read automatically.
- Case playbooks for 11 migrations, including Santander, CommBank, NAB, Capital One, a UK bank, an FR 2052a bank and TSB (`liq-case-playbooks.html`).
- Platform architecture page and the go-live strategy options page.
- **The master approach page** (`liq-migration-approach.html`): rules, architecture, the before/after switch toggle, switch groups and table types, phases, cutover runbook and script, the daily run, the evidence model, rollback without the legacy flow, Config and reruns, every object by name, test scenarios (R, S, U, P, H and C series), risks, and open questions.
- Project docs: `claude/liq-migration-context.md`, `claude/liq-migration-approach.md`, `claude/liq-recommended-golive.md`, `claude/liq-golive-research-findings.md`.
