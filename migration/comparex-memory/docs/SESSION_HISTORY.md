# Session history — how this design was reached

Condensed record of the design conversation (claude.ai, October 2026), so anyone picking this
up knows *why* things are the way they are.

1. **Memory concepts.** Agreed taxonomy: working, session, semantic (facts), preferences,
   episodic, procedural (playbooks), core/pinned, long-term, shared (team/org), entity memory.
   Write discipline matters more than retrieval: provenance, confidence, supersede instead of
   overwrite, decay, distinguish user decisions from agent suggestions.
2. **Stack.** Candidates discussed (Postgres + pgvector, Letta/Mem0/Zep, Snowflake Cortex).
   Constraint surfaced: enterprise setup, **no LLM access for the memory layer and no ability to
   host models**. Available: **SQLite, Snowflake, Python**.
3. **Embeddings without a model.** Chosen: TF-IDF + LSA (scikit-learn), FTS5/BM25 for keyword
   search. Alternatives noted: random indexing, PPMI+SVD, Doc2Vec trained locally, structured
   feature vectors, graph embeddings.
4. **Generic prototype** (`prototype/`): SQLite + Snowflake memory with working/session state,
   team/org scopes, rule-based session summaries. Superseded by the Comparex design.
5. **Comparex context.** Deterministic table compare → issue MD → Copilot CLI triage → handoff
   MD → Amp resolves and commits. Requirement: **do not change the existing system**; add memory
   so agents know which resolution fits which issue, known observations, and the fastest path.
6. **Key design decision:** match issues by **structural signatures** from the compare output,
   and judge fixes by **later Comparex runs** (ground truth), not by agent claims.
7. **System design doc** written (see `SYSTEM_DESIGN.md`).
8. **Implementation guide** with per-phase specs, acceptance tests and Amp prompts.
9. **Adaptation rule added:** the guide is guidance. First principles are fixed; everything
   else adapts to the existing build. Phase 0 makes Amp write `ALIGNMENT.md` (reuse / extend /
   add) before any code. Reuse by import; existing-code changes only additive and approved.
10. **Packaging** into this kit for Claude Code to push to GitHub, so the enterprise repo can
    pull it and Amp can execute.

## Open decisions (also in guide section 16)
- Memory files in `.memory/` inside the repo vs a shared path.
- Verification window 14 days, reopen window 30 days.
- One central ingester vs one per pipeline machine.
- Whether commits reliably reference issue IDs (fallback linking exists either way).
