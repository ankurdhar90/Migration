# Comparex Memory Kit

Everything needed to add a memory layer to the Comparex pipeline: design, implementation
guide, step-by-step prompts for Amp, tested reference code, templates, and the decision history.

## First: convert the Python files back to `.py`

Every Python file in this kit is stored as `<name>.py.txt` (for example
`reference/comparex_memory/signature/hashing.py.txt`). Before running tests or using the
reference code, remove the `.txt` ending from all of them. Run one of these from this folder
(`migration/comparex-memory/`):

PowerShell (Windows):
```powershell
Get-ChildItem -Recurse -Filter *.py.txt | Rename-Item -NewName { $_.Name -replace '\.txt$', '' }
```

Bash (macOS, Linux, Git Bash):
```bash
find . -name '*.py.txt' -exec sh -c 'mv "$1" "${1%.txt}"' _ {} \;
```

Afterwards there should be 18 `.py` files and no `.py.txt` files left. Nothing else in the
kit needs renaming.

**Two phased versions**
- **Version 1, SQLite only** (`v1-sqlite/`): Phases 0–7, local memory, no Snowflake.
- **Version 2, SQLite + Snowflake** (`v2-sqlite-snowflake/`): version 1 plus Phase 8, which
  syncs memory to Snowflake so it is shared and long-term. Upgrading from version 1 redoes nothing.

**Who does what**
- **Claude Code** (outside the enterprise): places this folder in the GitHub repo's migration
  folder and pushes it. See `CLAUDE.md`.
- **Amp** (inside the enterprise): builds the memory layer against the real codebase, phase by
  phase, using the prompts. See `START_HERE.md`.
- **You**: pick the version, review `ALIGNMENT.md` after Phase 0 and each phase's output, and
  add the one agent instruction line at the end.

## Contents
| Path | What it is |
| --- | --- |
| `START_HERE.md` | Pick a version |
| `html/` | Picture-based, interactive explainer pages. Open `html/index.html` in a browser; no internet or install needed |
| `v1-sqlite/` | Version 1 run order (`START_HERE.md`) and prompts 00–08 |
| `v2-sqlite-snowflake/` | Version 2 run order, its two extra prompts, and the Snowflake DDL |
| `CLAUDE.md` | Context and tasks for Claude Code |
| `docs/IMPLEMENTATION_GUIDE.md` | The full build guide for both versions: first principles, specs, tests, prompts |
| `docs/SYSTEM_DESIGN.md` | One-page design with architecture diagram |
| `docs/SESSION_HISTORY.md` | Why the design is the way it is |
| `reference/` | Tested reference code shared by both versions: schema, type parsing, value patterns, hashing, MD extractor, scoring, starting config |
| `templates/` | `ALIGNMENT.md` template and an example memory file |
| `prototype/` | Earlier generic memory prototype (superseded, for reference) |

## Verify the reference code
Convert the Python files first (see the top of this file), then:
```bash
cd reference
pip install pyyaml pytest
python -m pytest -q        # 13 tests
```
