# Prompt 0 — Give Amp the context (send once, first)

Paste the block below into Amp.

```text
You are implementing the Comparex memory layer in this repository.
The full specification is in migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md. Read the whole file now,
especially section 2 (Ground rules), section 5 (Configuration) and section 6 (Data model).

This guide was written without seeing our code. Treat it as guidance: the first principles
in section 0.1 are fixed; module names, layout, config format and similar details are defaults
that you adapt to the existing build (section 0.2). Reuse existing code by import, keep changes
minimal, and never rewrite or duplicate what already exists. When the guide and the existing
build disagree, the existing build wins as long as the invariants hold; record the deviation
in migration/comparex-memory/docs/ALIGNMENT.md.

Hard constraints, apply to every task I give you:
1. Do not change pipeline behavior or outputs. Do not edit issue/triage/handoff Markdown files,
   agent prompts, or agent configuration. Any change to existing code must first be proposed
   in migration/comparex-memory/docs/ALIGNMENT.md with its exact diff and approved by me (section 0.3).
2. The memory layer may only write files inside the configured memory_dir, and only through
   one write-guard function.
3. No LLM or hosted-model calls. Prefer libraries already in the repo; adding a new
   dependency needs my approval.
4. Never persist raw data values from compare results.
5. Output must be deterministic. Fix all random seeds.
6. A file that fails to parse is logged to ingest_errors and skipped; never abort a run.
7. Nothing about file formats is hard-coded; read it from memory_config.yaml.

We will start with Phase 0 (discovery and alignment, no code), then build in 7 phases.
I will give you one phase at a time. For each phase:
- Follow the approved migration/comparex-memory/docs/ALIGNMENT.md: reuse what it says to reuse, and use its
  layout and names instead of the guide's defaults.
- Implement only that phase.
- Write the tests listed in its acceptance criteria and make them pass.
- At the end, print a short summary: files created, how to run the tests, and anything you
  had to assume. Put assumptions in migration/comparex-memory/docs/ASSUMPTIONS.md.

Do not start coding yet. Reply with a short summary of the design in your own words and
any questions about the spec.
```
