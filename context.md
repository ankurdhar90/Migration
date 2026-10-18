# LIQ Migration: Context

_Last updated: 2026-10-18. Owner: Ankur (project lead). Read this first, then `decisions.md`, `actions.md` and `agent.md`._

## What this project is
This is a platform migration from SQL Server to Snowflake for the **Liquidity (LIQ) tier-1 interface tables**. In this phase, only the data that fills the tier-1 tables moves to Snowflake. Everything that consumes tier-1 (tier-2 / Liquidity Enrichment, other modules and reports) stays on SQL Server, unchanged. Moving Liquidity itself is not signed off yet. It will come later, through a **parallel Liquidity database**.

Status as of 2026-10-18: **in UAT.** Snowflake results are produced and copied into SQL Server, and reconciliation is running. The team now has to decide how to cut over, and define the interim (UAT) test scenarios and the go-live test scenarios.

## Architecture: SQL Server (legacy, production today)
Three layers, plus Liquidity:
1. **TDM_Staging** database: source-system data lands here.
2. **TDM_CDM** database (common data model): loaded from staging by procedures. The modules that run here are enrichment, logical relationships, GL segments, plugs/reconciliations/business event indicators, customer model and segmentation, and others. **Most surrogate keys are created here.**
3. **LIQ schema inside TDM_CDM**: procedures per instrument (deposits, loans, asset securities, derivatives, FX) holding the logic that shapes data for Liquidity tier-1.
4. **Liquidity database (DAL), on a different server**: tier-1 tables in the `Transaction`, `Reference` and `Config` schemas (example: `Transaction.TBLDeposits`). Tier-1 row keys are **IDENTITY** columns. Tier-1 keeps **full history**. Tier-2 procedures (for example deposit enrichment) read tier-1 and produce the liquidity reporting.

**Load mechanics (confirmed):** Control-M runs a wrapper script, which runs `dtexec` with an SSIS package configuration stored in SQL Server, plus parameters. The SSIS package then:
1. deletes the tier-1 rows for the business date
2. connects to TDM_CDM through a **SQL Server client alias** and runs the LIQ procedure
3. streams the procedure's result set into the tier-1 destination table.

Transaction tables use delete by business date and reload. Reference tables are truncated and reloaded. Config tables are maintained by the project team. SSIS is the slow step.

## Architecture: Snowflake (target)
Snowflake mirrors the same three layers: TDM_Staging (the same source data), then TDM_CDM (the same modules, recalculated, with its own keys), then the Liquidity schema procedures, which load **Snowflake DAL Liquidity tier-1 only**. Snowflake holds **no tier-1 history**. Control-M orchestrates Snowflake as well.

## The bridge (built by the project team)
- SQL Server schemas **SnowInTransactions, SnowInReference, SnowInConfigs** (the user mentioned four schemas; the fourth is not named yet). Each has the **same table structures** as its counterpart, for example `SnowInTransactions.TBLDeposits`.
- **DMVA** is an in-house tool that copies Snowflake tier-1 tables into the SnowIn tables.
- **Three-way reconciliation (running):**
  1. Snowflake tier-1 against SnowIn (checks the DMVA copy)
  2. Snowflake tier-1 against SQL Server tier-1 (parity)
  3. SnowIn against SQL Server tier-1 (a second check from the SQL Server side)

## Environments
- **Production:** legacy, live, the baseline numbers.
- **UAT:** production-like, with the same sources and cut-off and full tier-1 history. Legacy SSIS loads tier-1 in UAT too. There is **no other environment**. Interim testing happens in UAT and is compared against **production's numbers**.

## Facts that shape the design
- **Keys:** surrogate keys differ between the platforms, because each CDM creates its own. Reconciliation uses **business keys and reference codes** (GL product code, centre code), never IDs. **Tier-2 joins on codes, not IDs.**
- **Identity:** at the switch, history is copied with the original identity values, and new IDs must be **greater than the SQL Server maximum** up to the previous business day.
- **Timing:** Snowflake and DMVA output lands **earlier** than the legacy path.
- **Config:** the project team owns it and can change anything. Any repoint changes the SSIS config **and** the alias together.
- **Reruns:** previous-day reruns on the new path are only possible once history has been copied into the renamed or new tables.
- **After the switch, there is no flow from TDM_CDM into the legacy tables.** The SSIS load for that table stops.

## Key artifacts (claude.ai, private to the owner until shared)
| Page | URL | Status |
|---|---|---|
| **LIQ Migration Approach** (master) | https://claude.ai/artifact/7ohXU9AWXfsxKVw3QDcUhk | **Current** |
| LIQ Recommended Go-Live | https://claude.ai/artifact/4DY3FtuvaxhBCve9KCyHko | Superseded by the master |
| Migration Case Playbooks (11 cases) | https://claude.ai/artifact/P5VLeyzfgvUjAVhz6GeYPY | Background |
| How Others Went Live (research) | https://claude.ai/artifact/LyhEroNYBZCSaYCLBMbDmH | Background |
| LIQ Go-Live Strategy (SteerCo options) | https://claude.ai/artifact/AYgXuawdPebgZ9BrrbS6ku | Partly superseded |
| LIQ Platform Architecture | https://claude.ai/artifact/UJKaxtoVXM4xAaNDjpAkrx | Background |
| LIQ Go-Live by Rename / Liquidity tier-1 cutover | 5cztN1j7KiD2ZXMkpP4LEG / LbvnpL8nfQbDGPcCnUj1Ai | Superseded |

Local copies of the HTML pages are in `C:\Projects\Projects\Migration\`. Project docs: `claude/liq-*.md` in the claude.ai project "LIQ Migration".
