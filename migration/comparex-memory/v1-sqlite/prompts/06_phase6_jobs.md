# Phase 6

Paste the block below into Amp.

```text
Implement Phase 6 (Scheduled jobs) from
migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 12.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/jobs.py, extend the CLI with `memctl jobs run <name>`, and write tests.

Requirements:
- Jobs exactly as in 12.1, each taking a `now` parameter.
- Jobs run against the local SQLite database only. Do not add any Snowflake code,
  connection or dependency (that is version 2, section 13b).

Write the tests in 12.2, run everything and report. Then propose the scheduler entries for
`memctl ingest --watch` (or a cron cycle) and each job, using the scheduler that already runs
Comparex.
```
