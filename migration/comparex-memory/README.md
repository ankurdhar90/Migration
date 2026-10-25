# Comparex Memory Kit

Everything needed to add a memory layer to the Comparex pipeline: design, implementation
guide, step-by-step prompts for Amp, tested reference code, templates, and the decision history.

**Who does what**
- **Claude Code** (outside the enterprise): places this folder in the GitHub repo's migration
  folder and pushes it. See `CLAUDE.md`.
- **Amp** (inside the enterprise): builds the memory layer against the real codebase, phase by
  phase, using the prompts. See `AMP_START_HERE.md`.
- **You**: review `ALIGNMENT.md` after Phase 0 and each phase's output; add the one agent
  instruction line at the end.

## Contents
| Path | What it is |
| --- | --- |
| `AMP_START_HERE.md` | Run order for the enterprise side |
| `CLAUDE.md` | Context and tasks for Claude Code |
| `docs/IMPLEMENTATION_GUIDE.md` | The full build guide: first principles, specs, tests, prompts |
| `docs/SYSTEM_DESIGN.md` | One-page design with architecture diagram |
| `docs/SESSION_HISTORY.md` | Why the design is the way it is |
| `prompts/` | Each Amp prompt as its own file, in run order |
| `reference/` | Tested reference code: schema, type parsing, value patterns, hashing, MD extractor, scoring, Snowflake DDL, starting config |
| `templates/` | `ALIGNMENT.md` template and an example memory file |
| `prototype/` | Earlier generic memory prototype (superseded, for reference) |

## Verify the reference code
```bash
cd reference
pip install pyyaml pytest
python -m pytest -q        # 12 tests
```
