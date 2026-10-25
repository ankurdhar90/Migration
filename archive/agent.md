# Instructions for agents working on the LIQ Migration

_Last updated: 2026-10-18._

## Read first
1. `context.md`: what the system is and where things stand.
2. `decisions.md`: what has been decided, what is only proposed, and what has been **superseded** (never re-propose those).
3. `actions.md`: open questions and next actions.
4. The master page: **LIQ Migration Approach**, https://claude.ai/artifact/7ohXU9AWXfsxKVw3QDcUhk (local copy: `C:\Projects\Projects\Migration\liq-migration-approach.html`).

## Rules you must not break
- Only **tier-1 interface tables** change. Never propose changing or repointing tier-2 (for example deposit enrichment), reports or anything after tier-1.
- Tier-2 reads **real tables under their original names**. **No synonyms**, no views in place of tables.
- **After a switch there is no flow from TDM_CDM into legacy tables.** Don't propose shadow or backup loading.
- UAT (production-like) is the only rehearsal environment. Production is the baseline. Don't assume any other environment.
- Reconcile on business keys and reference codes, never surrogate IDs.
- Use real names in examples: `Transaction.TBLDeposits`, `SnowInTransactions.TBLDeposits`, `LegacyTransactions.TBLDeposits`. Never use placeholder labels like "Green.X".

## How the project lead (Ankur) likes to work
- Ask clarifying questions **one at a time**, and wait for the answer before asking the next.
- Challenge the design with counter-questions, but don't override confirmed facts.
- Always **separate confirmed facts from assumptions**, and say which is which.
- Prefer **diagrams and visuals** over text. Explain in **plain language** when asked.
- Keep replies concise. He'll say when you've drifted or gone too narrow, so step back to the whole implementation when that happens.
- He is in Australia/Sydney (UTC+11).

## Where things live
- **Local folder:** `C:\Projects\Projects\Migration\` holds the HTML pages and these markdown files. It's reachable through the remote-devices tools when the computer is linked.
- **claude.ai project "LIQ Migration":** docs under `claude/` (`liq-migration-context.md`, `liq-migration-approach.md`, `liq-recommended-golive.md`, `liq-golive-research-findings.md`). Update them when decisions change.
- **Artifacts:** see the table in `context.md`. Update an existing artifact by its URL, rather than creating a new page, unless the user asks for a new one.

## Visual conventions for pages
- Fonts: Archivo (display and body) with IBM Plex Mono (code and names), from Google Fonts.
- Colour tokens with light and dark modes: legacy = purple, Snowflake = teal, gate/checks = amber, rollback/risk = red, OK = green.
- Hand-written inline SVG diagrams. Wide diagrams scroll horizontally on phones. A before/after toggle with animated flows for switch diagrams.
- Timelines use one shared template: legacy lane on top, new lane below, shaded side-by-side period, numbered steps, gate markers.

## How to update these files
- When the project lead confirms something, move it from Proposed to Confirmed in `decisions.md`, with the date.
- Add new open questions to `actions.md`, and move answered ones into `context.md` or `decisions.md`.
- Keep `context.md` factual. Put choices in `decisions.md`.
