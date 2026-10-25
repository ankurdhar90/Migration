# CLAUDE.md — handoff from the claude.ai design session

You are picking up a design session that happened in claude.ai. Read this file, then
`docs/SESSION_HISTORY.md`, `docs/SYSTEM_DESIGN.md` and `docs/IMPLEMENTATION_GUIDE.md`
(section 0 first).

## The user's situation
- Enterprise environment. Project **Comparex** compares tables (Snowflake vs SQL Server, SQL
  Server vs SQL Server) deterministically at column level and reports differences.
- Downstream, **Copilot CLI** agents create issue and triage MD files; a handoff MD goes to
  **Amp**, which resolves and commits. Handoffs between agents are Markdown files.
- The memory layer must **not change the existing system**. It must use only **Python, SQLite
  and Snowflake**: no LLM calls, no hosted models.
- Real files and code are **only inside the enterprise**. You cannot see them. Amp, running
  inside the enterprise, does the real implementation using this kit.

## What this kit is
A self-contained folder (this directory) with the design, the implementation guide, per-phase
Amp prompts, tested reference code for the pure modules, templates and the session history.
The enterprise app pulls it from GitHub and Amp executes the prompts.

## Your tasks
1. **Place the kit in the user's GitHub repo** at `migration/comparex-memory/` (ask the user for
   the repo and the exact migration folder name if not obvious). If the folder name differs,
   update every reference to `migration/comparex-memory` in this kit:
   `grep -rl "migration/comparex-memory" . | xargs sed -i 's#migration/comparex-memory#<new path>#g'`
2. **Verify**: Python files are stored as `*.py.txt`; convert them first (commands in
   `README.md`), then `cd reference && pip install pyyaml pytest && python -m pytest -q`
   (13 tests pass). Keep them as `.py.txt` in the repo.
3. **Commit and push** on a new branch (e.g. `add-comparex-memory-kit`) and open a pull request,
   unless the user asks to push directly. Do not modify anything else in their repo.
4. **Optional, only if the user asks** (keep everything inside this folder):
   - Extend `reference/` with more pure modules from the guide (recall ranking, memory-file
     renderer, verifier logic on an in-memory SQLite DB) plus tests. Follow guide sections 10–11.
   - Build `reference/tests/fixtures/make_fixture_repo.py` per guide section 14.
   - Keep the golden hash values in `reference/tests/test_signatures.py` unchanged; changing
     hashing invalidates all stored memory.

## Rules (from the guide, section 0)
- First principles in 0.1 are fixed; everything else is a default that Amp adapts to the
  existing build. Do not turn the kit into a rigid framework.
- No LLM or model calls anywhere in memory code. Deterministic output.
- No real data values, table names or company details in this kit; fixtures are synthetic.

## State at handoff
- Done: design doc, implementation guide (with Phase 0 alignment and adapt-don't-rewrite rules),
  reference code (schema, type map, value patterns, hashing, entity name normalization,
  Markdown extractor, scoring) with 13 passing tests, templates, prototype.
- Kit placed in the repo at `migration/comparex-memory/` and pushed to `main`.
- Split into two phased versions (guide section 0.4): `v1-sqlite/` (prompts 00–08, SQLite
  only, Phase 6 is scheduled jobs) and `v2-sqlite-snowflake/` (version 1 plus a context prompt
  and Phase 8 Snowflake sync, with the Snowflake DDL generated from the schema). Shared
  `docs/`, `reference/` and `templates/` serve both.
- Not done (by design, needs the enterprise codebase): everything in Phases 0–8 that touches
  real files, Comparex result formats, git history, scheduling and Snowflake credentials.
- Open decisions: see `docs/SESSION_HISTORY.md`.
