# Phase 1

Paste the block below into Amp.

```text
Implement Phase 1 (Foundations) from migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md section 7.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create: comparex_memory/{__init__,config,guard,timeutil,cli}.py,
comparex_memory/store/{__init__,db}.py, comparex_memory/store/schema.sql (copy section 6.1
exactly), memory_config.yaml (copy section 5 as the starting point), pyproject.toml entry for
the memctl console script, and tests.

Requirements:
- Config is loaded once into frozen dataclasses; invalid config raises ConfigError with the
  failing key in the message.
- guard.safe_write_text is the only function in the package that writes files. It writes
  atomically and refuses any resolved path outside memory_dir, including via symlinks.
- db.connect enables WAL and foreign keys; db.migrate is idempotent and records
  schema_version in the meta table.
- db.upsert(conn, table, row, key_cols) always sets updated_at with timeutil.now_iso().
- memctl init creates memory_dir and the database.

Tests to write (pytest): config validation errors, guard refusals (relative escape,
absolute path, symlink escape), idempotent init, a static scan proving no file-writing calls
exist outside guard.py, and tests/test_guard_tree.py that hashes all files outside .memory/
before and after running memctl init on the fixture repo and asserts nothing changed.
For the fixture repo, create tests/fixtures/make_fixture_repo.py as described in section 14
(minimal version is fine for now: a few MD files and a git repo with two commits).

When done, run the tests and report results.
```
