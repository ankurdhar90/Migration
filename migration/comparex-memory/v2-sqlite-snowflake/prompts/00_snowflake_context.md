# Prompt 0 for version 2 — add Snowflake to a working version 1 (send once, first)

Send this only after version 1 is complete: Phases 0–7 accepted and memory files in use.
Paste the block below into Amp.

```text
Version 1 of the Comparex memory layer (SQLite only) is built and in use. We are now adding
version 2: Snowflake as the shared, long-term copy of the SQLite memory. Read
migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md sections 0.4, 6.2 and 13b, and
migration/comparex-memory/docs/ALIGNMENT.md.

Version 2 is additive. Everything from version 1 keeps working unchanged, and with
snowflake.enabled set to false the system behaves exactly like version 1.

All version 1 hard constraints still apply, with these two extensions:
1. Besides memory_dir, the memory layer may write to the Snowflake memory schema
   (default COMPAREX_MEMORY), and nowhere else in Snowflake.
2. snowflake-connector-python is an allowed dependency. If the repo already has a Snowflake
   connection module, reuse it instead.

Before coding, add a "Version 2" section to ALIGNMENT.md: the existing Snowflake access code
to reuse, how credentials are provided today, the target test and production schemas, the
roles that need access, and any proposed changes to existing code (with exact diffs; prefer
none). Then stop and wait for my review.
```
