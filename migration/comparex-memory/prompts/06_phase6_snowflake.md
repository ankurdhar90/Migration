# Phase 6

Paste the block below into Amp.

```text
Implement Phase 6 (Snowflake sync and scheduled jobs) from
migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 12.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/store/snowflake_sync.py, comparex_memory/jobs.py, the full
snowflake/ddl.sql (every synced table from 6.1, mapped as described in 6.2), extend the CLI
with `memctl sync push|pull` and `memctl jobs run <name>`, and write tests.

Requirements:
- Connection parameters only from environment variables or the standard Snowflake
  connection config; never logged.
- Push uses temporary stage tables + MERGE keyed on primary keys, batches of 1000, and the
  sync_state watermarks. Pull upserts only newer rows, then rebuilds the text index.
- Jobs exactly as in 12.2, each taking a `now` parameter.
- Unit tests use a fake connector; add an optional integration test (skipped unless
  COMPAREX_MEMORY_IT=1) that runs the round trip in 12.3 against a test schema.

Run tests and report. Do not run anything against production Snowflake.
```
