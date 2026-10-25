# Version 2: SQLite + Snowflake (enterprise side)

Version 1 plus one phase. SQLite stays the fast local store that agents read from; Snowflake
becomes the shared, long-term copy, so a new machine or another team pulls the full history.
With `snowflake.enabled: false` in the config, version 2 behaves exactly like version 1.

## Run order

**Starting fresh:** run every step of version 1 first (`../v1-sqlite/START_HERE.md`), up to and
including Phase 7. Then continue below.

**Upgrading a running version 1:** start below. Nothing in version 1 is rebuilt.

| Step | File to paste into Amp | Review before continuing |
| --- | --- | --- |
| V2-0 | `prompts/00_snowflake_context.md` | Version 2 section of `../docs/ALIGNMENT.md`: credentials, schemas, roles. **Approve before any code.** |
| V2-1 (Phase 8) | `prompts/01_phase8_snowflake_sync.md` | Version 1 tests still green; round trip on a test schema |
| Go-live | Set `snowflake.enabled: true`, create `COMPAREX_MEMORY` in production with role-based access, run `memctl sync push` once | Rows in Snowflake match the local counts from `memctl stats` |

The agent instruction line (version 1, last step) does not change: agents keep reading the
local memory files.

## Files in this folder
| Path | What it is |
| --- | --- |
| `prompts/` | The two version 2 prompts |
| `snowflake/ddl.sql` | Snowflake DDL generated from `../reference/comparex_memory/store/schema.sql` (guide section 6.2) |

Rules that never change (guide section 0.1) apply to both versions.
