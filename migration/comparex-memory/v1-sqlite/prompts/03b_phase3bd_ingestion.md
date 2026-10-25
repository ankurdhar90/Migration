# Phase 3b–3d

Paste the block below into Amp.

```text
Implement Phase 3 (Ingestion) steps 3b to 3d and 9.5 from
migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 9. Use the config produced in step 3a and the
formats described in migration/comparex-memory/docs/FORMAT_NOTES.md.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/ingest/{__init__,md_extractor,compare_adapters,compare_reader,
md_reader,git_reader,cursor,runner}.py and tests.

Requirements:
- md_extractor implements the five locator kinds exactly as in 9.2 and never raises on
  missing fields.
- compare_adapters defines Difference, CompareRun, the CompareAdapter protocol, the
  ReferenceJsonAdapter (for tests) AND a real adapter for our actual Comparex result format
  from FORMAT_NOTES.md. Register both; config selects one by name.
- compare_reader classifies value patterns from samples during ingestion and never stores
  samples anywhere (not in the DB, not in logs, not in caches).
- md_reader and git_reader follow 9.4, including commit grouping into attempts, fallback
  linking, handoff_only resolutions, resolution_type rules and approach_key detail sources.
- cursor + runner make ingestion idempotent; errors go to ingest_errors and never stop a cycle.
- CLI: memctl ingest, memctl ingest --backfill, memctl ingest --watch --interval N.

Extend tests/fixtures/make_fixture_repo.py (section 14) to cover every case in 9.6, write
the tests in 9.6, extend test_guard_tree.py, run everything and report. Then run
`memctl ingest --backfill` on the real repo (read-only) and report parse coverage from
ingest_errors.
```
