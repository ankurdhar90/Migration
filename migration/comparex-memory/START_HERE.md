# Start here (enterprise side)

The kit is at `migration/comparex-memory/` in the repo. Pick a version, then follow its run order.

| Version | Storage | When to choose it | Run order |
| --- | --- | --- | --- |
| 1 | SQLite only | One machine runs the memory layer; no Snowflake access needed yet | `v1-sqlite/START_HERE.md` |
| 2 | SQLite + Snowflake | Memory must survive machine loss, or be shared across machines or teams | `v2-sqlite-snowflake/START_HERE.md` |

The versions are phased: version 2 is version 1 plus one Snowflake phase. Starting with
version 1 and upgrading later costs nothing; no version 1 work is redone.

Both versions share `docs/` (the guide), `reference/` (tested code) and `templates/`.
