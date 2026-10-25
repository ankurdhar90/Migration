# LIQ Migration: Decision log

_Last updated: 2026-10-18._

Status key: **Confirmed** (stated by the project lead) · **Proposed** (recommended, not yet signed off) · **Superseded** (do not re-propose).

## Scope and constraints
| ID | Decision | Status | Why |
|---|---|---|---|
| D-01 | Only the Liquidity **tier-1 interface tables** change source in this phase. Tier-2, reports and everything after tier-1 stay on SQL Server, unchanged. | Confirmed | Moving Liquidity itself to Snowflake isn't signed off. A parallel Liquidity database comes later. |
| D-02 | Tier-2 procedures (for example deposit enrichment) **cannot be changed or repointed**. | Confirmed | Project constraint |
| D-03 | Tier-2 must keep reading **real tables under the original names** (for example `Transaction.TBLDeposits`). **No synonyms.** | Confirmed | Project constraint |
| D-04 | The go-live mechanism is a **rename**: the Snowflake-fed table takes the original tier-1 name. | Confirmed | Keeps tier-2 untouched |
| D-05 | The strategy is **designed per table** and repeated. Tables are switched in **switch groups**: a tier-2 process family plus every tier-1 table it reads. | Confirmed (per table) / Proposed (grouping) | Stops a tier-2 run mixing sources |
| D-06 | **After the switch, nothing flows from TDM_CDM into the legacy table.** The SSIS job for that table is disabled, and the legacy table is frozen at D-1 as the rollback point. | Confirmed | Project lead, 2026-10-17 |
| D-07 | UAT is production-like with the same sources and full history. It is the **only rehearsal environment**. Production is the baseline. | Confirmed | No other environment exists |

## Approach
| ID | Decision | Status | Why |
|---|---|---|---|
| D-10 | Interim testing = run the **production cutover runbook in UAT**, then run tier-2 unchanged on Snowflake data and compare it with **production** at tier-1, tier-2 output and report level, including a month-end and a quarter-end. | Proposed (built from confirmed facts) | Parity can only be proven before the production switch (see D-11) |
| D-11 | **Parity with legacy must be fully proven in UAT before the production switch.** After the switch, production only gets checks on DMVA's copy and day-on-day variance checks. | Proposed (follows from D-06) | Legacy no longer produces the switched data in production |
| D-12 | The cutover runs on the **T-1 evening, after the D-1 legacy batch and tier-2 finish**. The steps: truncate the SnowIn table; copy legacy history with IDENTITY_INSERT; reseed above the legacy maximum; run `ALTER SCHEMA LegacyTransactions TRANSFER Transaction.TBLDeposits` and `ALTER SCHEMA Transaction TRANSFER SnowInTransactions.TBLDeposits` in one transaction; reapply grants; disable the SSIS job; point DMVA's target at the renamed table; make tier-2's Control-M in-condition the DMVA load plus the gate. | Proposed | Keeps tier-2 unchanged and keeps identity continuous |
| D-13 | Empty the SnowIn table **before** the history copy. | Proposed | IDs that DMVA already generated could clash with legacy IDs |
| D-14 | **Table types:** Transaction tables: DMVA deletes the business date and inserts it in one transaction, with history copy and reseed. Reference tables: truncate and reload, no history. Config tables: the master moves to Snowflake at the switch, with a freeze around it. | Proposed | Mirrors today's load semantics |
| D-15 | The daily chain after the switch is Snowflake, then DMVA, then a **data gate** (counts, control totals and a hash against Snowflake; reference codes resolve), then tier-2, then reports. A failed gate stops tier-2. | Proposed | Control-M guarantees job order, not data completeness |
| D-16 | **Rollback** has to happen inside a time-boxed window: rename back, re-enable SSIS, run the **legacy catch-up** for every live date from TDM_CDM, then rerun tier-2. After the window, fix forward only. | Proposed | The legacy table is frozen at D-1 (D-06) |
| D-17 | **Config:** one master at a time, with a freeze from T-5 to the end of the first live week and a daily Config reconciliation. | Proposed | Avoids drift between the platforms |
| D-18 | Reconcile on **business keys and reference codes**, never surrogate IDs. | Confirmed | CDM keys differ between the platforms |
| D-19 | Gates: about 20 clean business days, including a month-end (and a quarter-end before the production switch); zero unexplained breaks; report owners' sign-off; rollback rehearsed and timed. | Proposed (numbers for SteerCo) | Research: parallel runs should span business cycles |

## Superseded (do not re-propose)
| ID | Idea | Why dropped |
|---|---|---|
| S-01 | **Alias-based "in and out"**: repoint the CDM alias to thin LIQ procedures on the Liquidity server that read SnowIn, keeping SSIS | UAT already gives a full parallel run against production, and the rename is the agreed mechanism |
| S-02 | **Synonyms / blue-green**: `Transaction.TBLDeposits` as a synonym pointing at a Snowflake table or a legacy table | D-03: real tables only |
| S-03 | **Legacy shadow or backup loading after the switch**: SSIS keeps loading the legacy table | D-06: no flow from CDM to legacy after the switch |
| S-04 | `ctl.SourceSwitch` control table plus synonyms (`liquidity_source_switch.sql`) | The earliest idea, replaced by the approaches above |
| S-05 | Same-date A/B in one environment (run legacy, swap, rerun) | UAT is compared with production instead |

## Research basis (summary)
Big bang is the documented failure mode (TSB 2018). The stronger programmes switched in slices or with an easy way back, ran side by side across business cycles, and used numeric exit criteria: CommBank (steel threads, 100% reconciliation), Santander (Dual Run, primary/secondary swap), a UK bank (Version 1, at least 6 months in parallel), NAB (cut scope, cold backup), Capital One (use case by use case). Full detail is on the research and case playbook pages.
