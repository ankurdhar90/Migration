# Phase 7

Paste the block below into Amp.

```text
Implement Phase 7 (Evaluation) from migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 13.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/evaluation.py and `memctl eval`. Use recall(..., exclude_after=...)
so no information from after an issue's opened_at is used. Produce the metrics in 13.1
overall, per diff_category and per engine_pair, written to memory_dir/eval_report.md through
guard.

Write the tests in 13.2, including the leakage test. Run on the fixture repo and on the real
backfill (read-only) and show me the report.
```
