# Phase 2

Paste the block below into Amp.

```text
Implement Phase 2 (Signatures and entities) from migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 8.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/signature/{__init__,type_map,value_patterns,hashing,entities}.py and tests.

Requirements:
- parse_type returns TypeInfo with base, params, family (from config type_map) and full.
- value_patterns.classify implements every rule kind in the table in 8.2 as a small pure
  function, applies rules in config order with min_share, and never logs or returns values.
- hashing.H and Signature exactly as specified in 8.3, including the normalization of parts.
  Add a golden test with frozen expected hash strings.
- entities.normalize_object, upsert_entities and record_type_fact as in 8.4, using
  db.upsert and db.stable_id from Phase 1. Facts are superseded, never overwritten.

These modules must be pure (no file I/O) except entities.py, which only touches the database
connection passed in. Run all tests and report.
```
