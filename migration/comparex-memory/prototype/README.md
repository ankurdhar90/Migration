# Prototype (superseded, kept for reference)

Generic agent-memory prototype from the design conversation, written before the Comparex
specifics were known. It demonstrates working, session, semantic, episodic, procedural and
shared (user/team/org) memory on SQLite + Snowflake with TF-IDF/LSA retrieval and no LLM.

The Comparex memory layer in `docs/IMPLEMENTATION_GUIDE.md` supersedes it. Useful ideas to
carry over if needed: working-state checkpoints, session summaries, and team/org scopes.
Do not deploy this code as is.
