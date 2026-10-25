# Phase 0

Paste the block below into Amp.

```text
Read migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md in full, especially section 0 (First principles and
how to adapt this guide). Treat the guide as guidance: the invariants in 0.1 are fixed, the
implementation details are defaults to adapt to this repository.

Do not write or change any code in this phase.

Study the existing build: how Comparex runs and stores results, how issue / triage / handoff
MD files are produced and named, how Copilot CLI agents and Amp are invoked, the config
system, DB access code, logging, CLI entry points, tests and scheduling. This is version 1
(SQLite only): note any existing Snowflake access code for version 2, but plan no Snowflake
work now.

Then write migration/comparex-memory/docs/ALIGNMENT.md with the six sections described in Phase 0: current build
summary, component map (reuse / extend / add for every guide component, with file paths),
proposed layout, proposed changes to existing code (with exact diffs; prefer none), deviations
from the guide (each checked against the invariants in 0.1), and questions.

Principles for your decisions:
- Reuse existing code by import wherever it already does the job.
- Smallest change that delivers the memory layer; no rewrites, no parallel copies of logic
  that already exists, no moving or renaming existing files.
- Pipeline behavior and outputs must stay exactly the same, with memory on or off.

Stop after writing ALIGNMENT.md and wait for my review.
```
