# Phase 5

Paste the block below into Amp.

```text
Implement Phase 5 (Recall, memory file, CLI) from migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md
section 11.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

Create comparex_memory/recall/{__init__,text_index,candidates,ranking,memory_file}.py, extend
cli.py with every command in 11.4, and write tests.

Requirements:
- text_index uses TF-IDF + TruncatedSVD(random_state=42) as in 11.1, with the FTS5 bm25
  fallback for small corpora; the pickle is written through guard.
- recall() follows the 8 steps in 11.2 and returns a RecallResult dataclass; it accepts
  `now` and `exclude_after` parameters.
- memory_file renders RecallResult using the exact template and rules in 11.3, stays within
  max_lines, and never drops blocker caveats.
- Wire text index updates and memory file regeneration into run_cycle for changed issues.
- Do NOT edit any agent instruction file; I will add the line from 11.5 myself.

Write the tests in 11.6 (including a golden memory file), run everything and report. Then
run memctl recall on three real issues and show me the generated files.
```
