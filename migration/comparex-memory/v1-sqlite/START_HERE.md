# Version 1: SQLite only (enterprise side)

Memory lives in a local SQLite database (`.memory/memory.db`). No Snowflake code, connection
or dependency. Version 2 can be added later without rebuilding anything
(`../v2-sqlite-snowflake/START_HERE.md`).

Prompts are in `prompts/`. Run them in order and review the output of each step before
sending the next prompt.

| Step | File to paste into Amp | Review before continuing |
| --- | --- | --- |
| 0 | `prompts/00_context.md` | Amp's summary and questions |
| 0a | `prompts/00a_phase0_alignment.md` | `../docs/ALIGNMENT.md` (template in `../templates/`). **Approve before any code.** |
| 1 | `prompts/01_phase1_foundations.md` | Tests green; init works; guard test |
| 2 | `prompts/02_phase2_signatures.md` | Golden hash test (reuse `../reference/` code) |
| 3a | `prompts/03a_phase3a_config_fitting.md` | Config + `../docs/FORMAT_NOTES.md` |
| 3b–d | `prompts/03b_phase3bd_ingestion.md` | Parse coverage on the real backfill |
| 4 | `prompts/04_phase4_outcomes.md` | Outcome and playbook counts |
| 5 | `prompts/05_phase5_recall.md` | Three real memory files |
| 6 | `prompts/06_phase6_jobs.md` | Job tests; proposed scheduler entries |
| 7 | `prompts/07_phase7_evaluation.md` | Evaluation report |
| Last | `prompts/08_agent_instruction_line.md` | Added by a human to the agents' instructions file |

Done when the guide's definition of done (section 15) passes, apart from the items marked
version 2.

Rules that never change (guide section 0.1): pipeline behavior unchanged, memory derived from
existing artifacts, structural matching first, fixes verified by Comparex, every claim cited,
memory advisory, no raw values stored, deterministic and model-free.
