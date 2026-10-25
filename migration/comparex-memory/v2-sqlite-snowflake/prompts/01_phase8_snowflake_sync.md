# Phase 8 (version 2)

Paste the block below into Amp after the version 2 section of ALIGNMENT.md is approved.

```text
Implement Phase 8 (Snowflake sync) from
migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 13b.
Follow migration/comparex-memory/docs/ALIGNMENT.md, including its version 2 section: reuse the
existing code it names, use its layout and names instead of the defaults below, and adapt
anything that conflicts with the existing build while keeping the invariants in section 0.1.

Create comparex_memory/store/snowflake_sync.py and the full snowflake/ddl.sql (start from
migration/comparex-memory/v2-sqlite-snowflake/snowflake/ddl.sql; every synced table from 6.1,
mapped as described in 6.2), add `snowflake.enabled` handling, extend the CLI with
`memctl sync push|pull`, and write tests.

Requirements:
- Connection parameters only from environment variables or the standard Snowflake
  connection config; never logged.
- Push uses temporary stage tables + MERGE keyed on primary keys, batches of 1000, and the
  sync_state watermarks. Pull upserts only newer rows, then rebuilds the text index.
- When snowflake.enabled is true, run_cycle pushes at the end of each cycle and the CLI pulls
  at startup. When it is false, no Snowflake code runs and nothing is imported from
  snowflake.connector.
- A failed push or pull is logged and retried next cycle; it never stops ingestion or recall.
- Unit tests use a fake connector; add an optional integration test (skipped unless
  COMPAREX_MEMORY_IT=1) that runs the round trip in 13b.3 against a test schema.

Run tests and report, including proof that all version 1 tests still pass with
snowflake.enabled false. Do not run anything against production Snowflake.
```
