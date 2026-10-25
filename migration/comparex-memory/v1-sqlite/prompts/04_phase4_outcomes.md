# Phase 4

Paste the block below into Amp.

```text
Implement Phase 4 (Outcomes, confidence, playbooks) from migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md
section 10.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/outcomes/{__init__,verifier,scoring,playbooks}.py and tests.

Requirements:
- verifier.verify_pending and verifier.mark_reopens exactly as in 10.1. All time comparisons
  use a `now` parameter (default timeutil.now_iso()) so tests are deterministic.
- scoring.confidence exactly as in 10.2, plus counts and median_minutes.
- playbooks.refresh_playbooks implements the status rules in 10.3 in the given order and
  never overwrites steps_md when edited_by_human = 1.
- Wire verifier and playbook refresh into ingest/runner.run_cycle after git ingestion.

Extend the fixture repo so every outcome type and every playbook rule in 10.4 is exercised,
write the tests in 10.4, run all tests and report. Then run on the real backfill and report
counts of outcomes by result and playbooks by status.
```
