"""
Agent memory with SQLite (local, fast) + Snowflake (long-term, shared).
No LLM, no hosted model. Retrieval = SQLite FTS5 BM25 + TF-IDF/LSA vectors.

Memory types
  working     -> working_state (+ checkpoints): the agent's scratchpad, survives crashes
  session     -> sessions + session_events: what happened in this run, resumable
  semantic    -> memories kind='fact'
  preference  -> memories kind='preference'
  episodic    -> memories kind='episode' (auto-created when a session ends)
  procedural  -> memories kind='procedure'
  core        -> memories pinned=1, always injected
  shared      -> memories scope='team' / 'org' (scope='user' = private)

pip install numpy scikit-learn snowflake-connector-python
"""
import json
import math
import pickle
import re
import sqlite3
import time
import uuid
from pathlib import Path

import numpy as np
from sklearn.decomposition import TruncatedSVD
from sklearn.feature_extraction.text import TfidfVectorizer

KINDS = ("fact", "preference", "episode", "procedure")
SCOPES = ("user", "team", "org")
EVENT_TYPES = ("user_message", "decision", "tool_call", "result", "error", "note")
SOURCE_CONFIDENCE = {"user": 0.9, "tool": 0.8, "system": 0.8, "agent": 0.5}
SOURCE_RANK = {"user": 3, "tool": 2, "system": 2, "agent": 1}
SCOPE_WEIGHT = {"user": 1.0, "team": 0.9, "org": 0.8}  # personal beats shared on ties
ORG_ID = "org"
MAX_CHECKPOINTS = 20

SCHEMA = """
-- Long-term memories (semantic, preference, episodic, procedural)
CREATE TABLE IF NOT EXISTS memories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,             -- who created it
  agent_id TEXT,
  scope TEXT NOT NULL CHECK (scope IN ('user','team','org')),
  scope_id TEXT NOT NULL,            -- user id, team id, or 'org'
  kind TEXT NOT NULL CHECK (kind IN ('fact','preference','episode','procedure')),
  mem_key TEXT,                      -- e.g. 'db.production' -> enables supersede
  content TEXT NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('user','agent','tool','system')),
  confidence REAL NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0,
  session_id TEXT,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  superseded_by TEXT,
  synced INTEGER NOT NULL DEFAULT 0,
  vector BLOB
);
CREATE INDEX IF NOT EXISTS idx_mem_scope ON memories(scope, scope_id, kind);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mem_key ON memories(scope, scope_id, mem_key)
  WHERE mem_key IS NOT NULL AND superseded_by IS NULL;

CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts
  USING fts5(content, content='memories', content_rowid='rowid');
CREATE TRIGGER IF NOT EXISTS mem_ai AFTER INSERT ON memories BEGIN
  INSERT INTO memories_fts(rowid, content) VALUES (new.rowid, new.content);
END;
CREATE TRIGGER IF NOT EXISTS mem_ad AFTER DELETE ON memories BEGIN
  INSERT INTO memories_fts(memories_fts, rowid, content)
  VALUES ('delete', old.rowid, old.content);
END;
CREATE TRIGGER IF NOT EXISTS mem_au AFTER UPDATE OF content ON memories BEGIN
  INSERT INTO memories_fts(memories_fts, rowid, content)
  VALUES ('delete', old.rowid, old.content);
  INSERT INTO memories_fts(rowid, content) VALUES (new.rowid, new.content);
END;

-- Session memory
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  goal TEXT,
  status TEXT NOT NULL CHECK (status IN ('active','completed','failed','abandoned')),
  outcome TEXT,
  summary TEXT,
  started_at REAL NOT NULL,
  last_active_at REAL NOT NULL,
  ended_at REAL,
  synced INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sess_active ON sessions(user_id, agent_id, status);

CREATE TABLE IF NOT EXISTS session_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL REFERENCES sessions(id),
  ts REAL NOT NULL,
  event_type TEXT NOT NULL,
  content TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_sess ON session_events(session_id, ts);

-- Working memory (current scratchpad) + checkpoint history for rollback
CREATE TABLE IF NOT EXISTS working_state (
  session_id TEXT PRIMARY KEY REFERENCES sessions(id),
  state TEXT NOT NULL,
  version INTEGER NOT NULL,
  updated_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS working_checkpoints (
  session_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  state TEXT NOT NULL,
  ts REAL NOT NULL,
  PRIMARY KEY (session_id, version)
);
"""


def _norm(text):
    return " ".join(text.lower().split())


class AgentMemory:
    def __init__(self, db_path="agent_memory.db", index_path="memory_index.pkl"):
        self.db = sqlite3.connect(db_path)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
        self.index_path = Path(index_path)
        self.tfidf, self.svd = None, None
        if self.index_path.exists():
            self.tfidf, self.svd = pickle.loads(self.index_path.read_bytes())

    # =========================================================
    # WORKING + SESSION MEMORY
    # =========================================================
    def start_session(self, user_id, agent_id, goal="", resume=True):
        """Returns (session_id, working_state). Resumes an unfinished session if any."""
        if resume:
            row = self.db.execute(
                "SELECT id FROM sessions WHERE user_id=? AND agent_id=? "
                "AND status='active' ORDER BY last_active_at DESC LIMIT 1",
                (user_id, agent_id)).fetchone()
            if row:
                self.log_event(row["id"], "note", "Session resumed")
                return row["id"], self.load_state(row["id"])
        sid, now = str(uuid.uuid4()), time.time()
        self.db.execute(
            "INSERT INTO sessions (id,user_id,agent_id,goal,status,started_at,"
            "last_active_at) VALUES (?,?,?,?, 'active', ?, ?)",
            (sid, user_id, agent_id, goal, now, now))
        self.db.execute("INSERT INTO working_state VALUES (?, '{}', 0, ?)", (sid, now))
        self.db.commit()
        return sid, {}

    def log_event(self, session_id, event_type, content):
        assert event_type in EVENT_TYPES, f"event_type must be one of {EVENT_TYPES}"
        now = time.time()
        self.db.execute("INSERT INTO session_events (session_id,ts,event_type,content) "
                        "VALUES (?,?,?,?)", (session_id, now, event_type, content))
        self.db.execute("UPDATE sessions SET last_active_at=? WHERE id=?",
                        (now, session_id))
        self.db.commit()

    def save_state(self, session_id, state: dict):
        """Checkpoint the agent's scratchpad (plan, step, partial results)."""
        now = time.time()
        row = self.db.execute("SELECT version FROM working_state WHERE session_id=?",
                              (session_id,)).fetchone()
        version = (row["version"] if row else 0) + 1
        blob = json.dumps(state, default=str)
        self.db.execute(
            "INSERT INTO working_state VALUES (?,?,?,?) ON CONFLICT(session_id) DO "
            "UPDATE SET state=excluded.state, version=excluded.version, "
            "updated_at=excluded.updated_at", (session_id, blob, version, now))
        self.db.execute("INSERT INTO working_checkpoints VALUES (?,?,?,?)",
                        (session_id, version, blob, now))
        self.db.execute("DELETE FROM working_checkpoints WHERE session_id=? "
                        "AND version <= ?", (session_id, version - MAX_CHECKPOINTS))
        self.db.execute("UPDATE sessions SET last_active_at=? WHERE id=?",
                        (now, session_id))
        self.db.commit()
        return version

    def load_state(self, session_id, version=None):
        """Current working state, or an older checkpoint to roll back to."""
        if version is None:
            row = self.db.execute("SELECT state FROM working_state WHERE session_id=?",
                                  (session_id,)).fetchone()
        else:
            row = self.db.execute("SELECT state FROM working_checkpoints WHERE "
                                  "session_id=? AND version=?",
                                  (session_id, version)).fetchone()
        return json.loads(row["state"]) if row else {}

    def session_history(self, session_id, last=20, event_types=None):
        q = "SELECT ts, event_type, content FROM session_events WHERE session_id=?"
        params = [session_id]
        if event_types:
            q += f" AND event_type IN ({','.join('?' * len(event_types))})"
            params += list(event_types)
        rows = self.db.execute(q + " ORDER BY ts DESC, id DESC LIMIT ?",
                               (*params, last)).fetchall()
        return [dict(r) for r in reversed(rows)]

    def end_session(self, session_id, outcome, status="completed",
                    share_scope="user", share_scope_id=None):
        """Rule-based summary -> stored on the session + promoted to an episode memory.
        share_scope='team' (with share_scope_id) lets teammates' agents learn from it."""
        assert status in ("completed", "failed", "abandoned")
        s = self.db.execute("SELECT * FROM sessions WHERE id=?", (session_id,)).fetchone()
        if not s or s["status"] != "active":
            return None
        events = self.session_history(session_id, last=10_000)
        counts = {}
        for e in events:
            counts[e["event_type"]] = counts.get(e["event_type"], 0) + 1
        decisions = [e["content"] for e in events if e["event_type"] == "decision"][-5:]
        errors = [e["content"] for e in events if e["event_type"] == "error"][-3:]
        mins = max(1, round((time.time() - s["started_at"]) / 60))

        parts = [f"Goal: {s['goal'] or 'n/a'}", f"Status: {status}",
                 f"Outcome: {outcome}", f"Duration: ~{mins} min",
                 "Activity: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items()))]
        if decisions:
            parts.append("Decisions: " + "; ".join(decisions))
        if errors:
            parts.append("Errors: " + "; ".join(errors))
        summary = " | ".join(parts)

        now = time.time()
        self.db.execute("UPDATE sessions SET status=?, outcome=?, summary=?, ended_at=?, "
                        "last_active_at=?, synced=0 WHERE id=?",
                        (status, outcome, summary, now, now, session_id))
        self.db.execute("DELETE FROM working_state WHERE session_id=?", (session_id,))
        self.db.execute("DELETE FROM working_checkpoints WHERE session_id=?",
                        (session_id,))
        self.db.commit()
        self.remember(s["user_id"], summary, kind="episode", source="system",
                      agent_id=s["agent_id"], session_id=session_id,
                      scope=share_scope, scope_id=share_scope_id)
        return summary

    def abandon_stale_sessions(self, max_idle_hours=24):
        """Close sessions nobody resumed. Run on a schedule."""
        cutoff = time.time() - max_idle_hours * 3600
        stale = self.db.execute("SELECT id FROM sessions WHERE status='active' "
                                "AND last_active_at < ?", (cutoff,)).fetchall()
        for r in stale:
            self.end_session(r["id"], "No activity; session abandoned", "abandoned")
        return len(stale)

    # =========================================================
    # LONG-TERM MEMORY (write)
    # =========================================================
    def remember(self, user_id, content, kind="fact", source="agent", key=None,
                 confidence=None, pinned=False, agent_id=None,
                 scope="user", scope_id=None, session_id=None):
        assert kind in KINDS and scope in SCOPES
        if scope == "user":
            scope_id = user_id
        elif scope == "org":
            scope_id = ORG_ID
        elif not scope_id:
            raise ValueError("scope='team' needs scope_id (the team id)")
        if scope == "org" and source == "agent":
            # stop unverified agent guesses from polluting everyone's memory
            raise ValueError("Agent-inferred memories can't be written to org scope")

        now = time.time()
        confidence = confidence if confidence is not None else SOURCE_CONFIDENCE[source]
        args = (user_id, agent_id, scope, scope_id, kind, key, content, source,
                confidence, pinned, session_id, now)

        # 1) Same key in the same scope -> supersede (unless new source is weaker)
        if key:
            old = self.db.execute(
                "SELECT * FROM memories WHERE scope=? AND scope_id=? AND mem_key=? "
                "AND superseded_by IS NULL", (scope, scope_id, key)).fetchone()
            if old:
                if _norm(old["content"]) == _norm(content):
                    return self._touch(old["id"])
                if SOURCE_RANK[source] < SOURCE_RANK[old["source"]]:
                    return old["id"]  # agent guess never overrides what the user said
                new_id = str(uuid.uuid4())
                self.db.execute("UPDATE memories SET superseded_by=?, synced=0, "
                                "updated_at=? WHERE id=?", (new_id, now, old["id"]))
                return self._insert(new_id, *args)

        # 2) Exact duplicate in the same scope -> refresh it
        for row in self.db.execute(
                "SELECT id, content FROM memories WHERE scope=? AND scope_id=? "
                "AND kind=? AND superseded_by IS NULL", (scope, scope_id, kind)):
            if _norm(row["content"]) == _norm(content):
                return self._touch(row["id"])

        return self._insert(str(uuid.uuid4()), *args)

    def forget(self, memory_id):
        """Soft delete: never retrieved again, still auditable in Snowflake."""
        self.db.execute("UPDATE memories SET superseded_by='forgotten', synced=0, "
                        "updated_at=? WHERE id=?", (time.time(), memory_id))
        self.db.commit()

    def _insert(self, mid, user_id, agent_id, scope, scope_id, kind, key, content,
                source, confidence, pinned, session_id, now):
        vec = self._embed([content])
        self.db.execute(
            "INSERT INTO memories (id,user_id,agent_id,scope,scope_id,kind,mem_key,"
            "content,source,confidence,pinned,session_id,created_at,updated_at,vector) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (mid, user_id, agent_id, scope, scope_id, kind, key, content, source,
             confidence, int(pinned), session_id, now, now,
             vec[0].tobytes() if vec is not None else None))
        self.db.commit()
        return mid

    def _touch(self, mid):
        self.db.execute("UPDATE memories SET updated_at=?, synced=0 WHERE id=?",
                        (time.time(), mid))
        self.db.commit()
        return mid

    # =========================================================
    # EMBEDDINGS (TF-IDF + LSA, no model)
    # =========================================================
    def _embed(self, texts):
        if self.tfidf is None:
            return None
        v = self.svd.transform(self.tfidf.transform(texts)).astype(np.float32)
        return v / (np.linalg.norm(v, axis=1, keepdims=True) + 1e-9)

    def rebuild_index(self, max_dims=128):
        """Refit LSA on all active memories. Run on a schedule (e.g. nightly)."""
        rows = self.db.execute("SELECT id, content FROM memories "
                               "WHERE superseded_by IS NULL").fetchall()
        if len(rows) < 10:
            return  # too few memories; keyword search alone is better here
        tfidf = TfidfVectorizer(ngram_range=(1, 2), stop_words="english",
                                sublinear_tf=True)
        X = tfidf.fit_transform([r["content"] for r in rows])
        dims = max(2, min(max_dims, X.shape[0] - 1, X.shape[1] - 1))
        self.tfidf, self.svd = tfidf, TruncatedSVD(n_components=dims).fit(X)
        self.index_path.write_bytes(pickle.dumps((self.tfidf, self.svd)))
        vecs = self._embed([r["content"] for r in rows])
        self.db.executemany("UPDATE memories SET vector=? WHERE id=?",
                            [(v.tobytes(), r["id"]) for v, r in zip(vecs, rows)])
        self.db.commit()

    # =========================================================
    # LONG-TERM MEMORY (read)
    # =========================================================
    @staticmethod
    def _visible(user_id, teams):
        """SQL filter: the user's private memories + their teams' + org-wide."""
        teams = list(teams or [])
        clause = "(m.scope='org' OR (m.scope='user' AND m.scope_id=?)"
        params = [user_id]
        if teams:
            clause += f" OR (m.scope='team' AND m.scope_id IN ({','.join('?' * len(teams))}))"
            params += teams
        return clause + ")", params

    def recall(self, user_id, query, k=5, teams=None, kinds=None,
               w_keyword=0.5, w_semantic=0.3, w_recency=0.1, w_conf=0.1):
        kinds = kinds or KINDS
        vis, vparams = self._visible(user_id, teams)
        rows = {r["id"]: r for r in self.db.execute(
            f"SELECT * FROM memories m WHERE {vis} AND m.superseded_by IS NULL "
            f"AND m.kind IN ({','.join('?' * len(kinds))})", (*vparams, *kinds))}
        if not rows:
            return []

        # Keyword score: SQLite FTS5 BM25 (lower = better, so negate)
        kw = {}
        tokens = re.findall(r"\w+", query)
        if tokens:
            fts_q = " OR ".join(f'"{t}"' for t in tokens)
            for r in self.db.execute(
                    f"SELECT m.id, -bm25(memories_fts) AS s FROM memories_fts "
                    f"JOIN memories m ON m.rowid = memories_fts.rowid "
                    f"WHERE memories_fts MATCH ? AND {vis}", (fts_q, *vparams)):
                if r["id"] in rows:
                    kw[r["id"]] = r["s"]
        top = max(kw.values(), default=0) or 1
        kw = {i: s / top for i, s in kw.items()}

        # Semantic score: cosine on LSA vectors
        sem = {}
        q = self._embed([query])
        if q is not None:
            for i, r in rows.items():
                if r["vector"]:
                    v = np.frombuffer(r["vector"], dtype=np.float32)
                    if v.shape == q[0].shape:
                        sem[i] = max(0.0, float(v @ q[0]))

        now = time.time()
        scored = []
        for i, r in rows.items():
            if i not in kw and sem.get(i, 0) < 0.3:
                continue  # not relevant enough
            recency = math.exp(-(now - r["updated_at"]) / 86400 / 30)
            score = (w_keyword * kw.get(i, 0) + w_semantic * sem.get(i, 0)
                     + w_recency * recency + w_conf * r["confidence"])
            scored.append((score * SCOPE_WEIGHT[r["scope"]], dict(r)))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [{**m, "score": round(s, 3), "vector": None} for s, m in scored[:k]]

    def core(self, user_id, teams=None):
        """Pinned memories from all visible scopes + the user's own preferences."""
        vis, vparams = self._visible(user_id, teams)
        return [dict(r) | {"vector": None} for r in self.db.execute(
            f"SELECT * FROM memories m WHERE {vis} AND m.superseded_by IS NULL AND "
            f"(m.pinned=1 OR (m.kind='preference' AND m.scope='user')) "
            f"ORDER BY m.scope, m.updated_at DESC", vparams)]

    def build_context(self, user_id, query, session_id=None, teams=None, k=5):
        """Everything the agent should see this turn, as one text block."""
        core = self.core(user_id, teams)
        seen = {m["id"] for m in core}
        rel = [m for m in self.recall(user_id, query, k, teams) if m["id"] not in seen]
        label = lambda m: m["scope"] if m["scope"] != "team" else f"team:{m['scope_id']}"

        lines = ["## Always true"] + [f"- ({label(m)}) {m['content']}" for m in core]
        lines += ["## Relevant memories"] + [
            f"- ({label(m)}, {m['kind']}, from {m['source']}) {m['content']}" for m in rel]
        if session_id:
            state = self.load_state(session_id)
            if state:
                lines += ["## Current task state", json.dumps(state, indent=1)]
            recent = self.session_history(session_id, last=8)
            if recent:
                lines += ["## Recent steps this session"] + [
                    f"- [{e['event_type']}] {e['content']}" for e in recent]
        return "\n".join(lines)

    # =========================================================
    # SNOWFLAKE SYNC
    # =========================================================
    def push_to_snowflake(self, sf_conn, mem_table="AGENT_MEMORY",
                          sess_table="AGENT_SESSIONS"):
        """Upsert unsynced memories and finished sessions into Snowflake."""
        cur = sf_conn.cursor()
        mems = self.db.execute("SELECT * FROM memories WHERE synced=0").fetchall()
        mem_sql = f"""
        MERGE INTO {mem_table} t USING (SELECT
          %(id)s ID, %(user_id)s USER_ID, %(agent_id)s AGENT_ID, %(scope)s SCOPE,
          %(scope_id)s SCOPE_ID, %(kind)s KIND, %(mem_key)s MEM_KEY,
          %(content)s CONTENT, %(source)s SOURCE, %(confidence)s CONFIDENCE,
          %(pinned)s PINNED, %(session_id)s SESSION_ID,
          TO_TIMESTAMP_NTZ(%(created_at)s) CREATED_AT,
          TO_TIMESTAMP_NTZ(%(updated_at)s) UPDATED_AT,
          %(superseded_by)s SUPERSEDED_BY) s
        ON t.ID = s.ID
        WHEN MATCHED THEN UPDATE SET CONTENT=s.CONTENT, CONFIDENCE=s.CONFIDENCE,
          PINNED=s.PINNED, UPDATED_AT=s.UPDATED_AT, SUPERSEDED_BY=s.SUPERSEDED_BY
        WHEN NOT MATCHED THEN INSERT (ID, USER_ID, AGENT_ID, SCOPE, SCOPE_ID, KIND,
          MEM_KEY, CONTENT, SOURCE, CONFIDENCE, PINNED, SESSION_ID, CREATED_AT,
          UPDATED_AT, SUPERSEDED_BY)
        VALUES (s.ID, s.USER_ID, s.AGENT_ID, s.SCOPE, s.SCOPE_ID, s.KIND, s.MEM_KEY,
          s.CONTENT, s.SOURCE, s.CONFIDENCE, s.PINNED, s.SESSION_ID, s.CREATED_AT,
          s.UPDATED_AT, s.SUPERSEDED_BY)"""
        for r in mems:
            d = dict(r)
            d.pop("vector")
            d["pinned"] = bool(d["pinned"])
            d["created_at"], d["updated_at"] = int(d["created_at"]), int(d["updated_at"])
            cur.execute(mem_sql, d)

        sessions = self.db.execute("SELECT * FROM sessions WHERE synced=0 "
                                   "AND status != 'active'").fetchall()
        sess_sql = f"""
        MERGE INTO {sess_table} t USING (SELECT %(id)s ID, %(user_id)s USER_ID,
          %(agent_id)s AGENT_ID, %(goal)s GOAL, %(status)s STATUS,
          %(outcome)s OUTCOME, %(summary)s SUMMARY,
          TO_TIMESTAMP_NTZ(%(started_at)s) STARTED_AT,
          TO_TIMESTAMP_NTZ(%(ended_at)s) ENDED_AT) s
        ON t.ID = s.ID
        WHEN NOT MATCHED THEN INSERT (ID, USER_ID, AGENT_ID, GOAL, STATUS, OUTCOME,
          SUMMARY, STARTED_AT, ENDED_AT)
        VALUES (s.ID, s.USER_ID, s.AGENT_ID, s.GOAL, s.STATUS, s.OUTCOME, s.SUMMARY,
          s.STARTED_AT, s.ENDED_AT)"""
        for r in sessions:
            d = dict(r)
            d["started_at"], d["ended_at"] = int(d["started_at"]), int(d["ended_at"])
            cur.execute(sess_sql, d)

        self.db.executemany("UPDATE memories SET synced=1 WHERE id=?",
                            [(r["id"],) for r in mems])
        self.db.executemany("UPDATE sessions SET synced=1 WHERE id=?",
                            [(r["id"],) for r in sessions])
        self.db.commit()
        return len(mems), len(sessions)

    def pull_from_snowflake(self, sf_conn, user_id, teams=None,
                            mem_table="AGENT_MEMORY"):
        """At session start: load the user's + their teams' + org memories."""
        teams = list(teams or [])
        where = "SCOPE='org' OR (SCOPE='user' AND SCOPE_ID=%s)"
        params = [user_id]
        if teams:
            where += f" OR (SCOPE='team' AND SCOPE_ID IN ({','.join(['%s'] * len(teams))}))"
            params += teams
        cur = sf_conn.cursor()
        cur.execute(f"""SELECT ID, USER_ID, AGENT_ID, SCOPE, SCOPE_ID, KIND, MEM_KEY,
            CONTENT, SOURCE, CONFIDENCE, PINNED, SESSION_ID,
            DATE_PART(EPOCH_SECOND, CREATED_AT), DATE_PART(EPOCH_SECOND, UPDATED_AT)
            FROM {mem_table} WHERE SUPERSEDED_BY IS NULL AND ({where})""", params)
        n = 0
        for row in cur.fetchall():
            row = list(row)
            row[10] = int(bool(row[10]))
            try:
                self.db.execute(
                    "INSERT INTO memories (id,user_id,agent_id,scope,scope_id,kind,"
                    "mem_key,content,source,confidence,pinned,session_id,created_at,"
                    "updated_at,synced) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1) "
                    "ON CONFLICT(id) DO UPDATE SET content=excluded.content, "
                    "confidence=excluded.confidence, pinned=excluded.pinned, "
                    "updated_at=excluded.updated_at, synced=1", row)
                n += 1
            except sqlite3.IntegrityError:
                pass  # a newer local memory holds this key; local wins until pushed
        self.db.commit()
        self.rebuild_index()
        return n


# =============================================================
# DEMO
# =============================================================
if __name__ == "__main__":
    import os
    for f in ("/tmp/demo_mem.db", "/tmp/demo_index.pkl"):
        if os.path.exists(f):
            os.remove(f)

    mem = AgentMemory("/tmp/demo_mem.db", "/tmp/demo_index.pkl")
    alice, bob, team = "alice", "bob", ["data-eng"]

    # Private, team and org memories
    mem.remember(alice, "Prefers weekly reports broken out by region",
                 kind="preference", source="user", key="report.format")
    mem.remember(alice, "Production database is Postgres on AWS RDS", source="user",
                 key="db.production", scope="team", scope_id="data-eng", pinned=True)
    mem.remember(alice, "ETL server restarts every Sunday 02:00 UTC; avoid jobs then",
                 source="tool", scope="org", pinned=True)
    mem.remember(alice, "To deploy the reporting service: run tests, build image, "
                 "push to registry, apply helm chart", kind="procedure",
                 source="tool", scope="team", scope_id="data-eng")
    for i in range(10):
        mem.remember(alice, f"Note {i} from weekly team meeting about roadmap")
    mem.rebuild_index()

    try:
        mem.remember(alice, "I think the CFO hates pie charts", scope="org")
    except ValueError as e:
        print("Blocked:", e)

    # Session with working memory, then a "crash"
    sid, state = mem.start_session(alice, "etl_agent", goal="Fix nightly ETL failure")
    mem.log_event(sid, "user_message", "The nightly ETL failed again")
    mem.log_event(sid, "tool_call", "Checked RDS metrics")
    mem.log_event(sid, "error", "RDS connection limit reached (max_connections=100)")
    mem.save_state(sid, {"plan": ["check metrics", "raise limit", "rerun job"], "step": 1})
    del mem  # simulate process crash

    mem = AgentMemory("/tmp/demo_mem.db", "/tmp/demo_index.pkl")
    sid2, state = mem.start_session(alice, "etl_agent", goal="Fix nightly ETL failure")
    print("Resumed same session:", sid2 == sid, "| state:", state)
    mem.log_event(sid, "decision", "Raise max_connections to 200 and add pooling")
    mem.save_state(sid, {**state, "step": 3})
    mem.log_event(sid, "result", "ETL rerun succeeded")

    print("\n--- Context Alice's agent sees mid-session ---")
    print(mem.build_context(alice, "ETL connection failing", session_id=sid, teams=team))

    print("\n--- Session summary (stored as an episode) ---")
    print(mem.end_session(sid, "ETL fixed by raising connection limit",
                          share_scope="team", share_scope_id="data-eng"))

    print("\n--- Bob (same team) asks a related question ---")
    print(mem.build_context(bob, "database connection limit ETL", teams=team))

    print("\n--- Carol (other team) sees only org-wide memory ---")
    print(mem.build_context("carol", "database connection limit ETL", teams=["marketing"]))
