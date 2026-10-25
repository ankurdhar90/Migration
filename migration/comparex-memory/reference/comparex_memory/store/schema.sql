PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Ground truth from Comparex ------------------------------------------------
CREATE TABLE IF NOT EXISTS compare_runs (
  run_id        TEXT PRIMARY KEY,
  started_at    TEXT NOT NULL,
  engine_pair   TEXT NOT NULL,          -- e.g. 'sqlserver->snowflake'
  source_object TEXT NOT NULL,          -- normalized 'db.schema.table' lowercase
  target_object TEXT NOT NULL,
  total_diffs   INTEGER NOT NULL,
  result_file   TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS run_differences (
  run_id        TEXT NOT NULL REFERENCES compare_runs(run_id),
  diff_key      TEXT NOT NULL,          -- deterministic, unique within run
  diff_category TEXT NOT NULL,
  column_ref    TEXT,
  rows_affected INTEGER NOT NULL DEFAULT 0,
  sig_l1        TEXT NOT NULL,
  sig_l2        TEXT NOT NULL,
  sig_l3        TEXT NOT NULL,
  fields_json   TEXT NOT NULL,          -- signature fields, NO raw values
  updated_at    TEXT NOT NULL,
  PRIMARY KEY (run_id, diff_key)
);
CREATE INDEX IF NOT EXISTS idx_rundiff_l1 ON run_differences(sig_l1);

-- Episodic: issues ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issues (
  issue_id        TEXT PRIMARY KEY,
  source_file     TEXT NOT NULL,
  run_id          TEXT,
  engine_pair     TEXT,
  source_object   TEXT,
  target_object   TEXT,
  title           TEXT,
  description     TEXT,
  triage_file     TEXT,
  triage_category TEXT,
  severity        TEXT,
  triage_notes    TEXT,
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','triaged','in_progress','resolved',
                                    'verified','reopened','wont_fix')),
  rows_affected   INTEGER,
  opened_at       TEXT NOT NULL,
  triaged_at      TEXT,
  resolved_at     TEXT,
  verified_at     TEXT,
  text_vector     BLOB,                 -- LSA vector, float32
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_issues_objects ON issues(source_object, target_object);

CREATE VIRTUAL TABLE IF NOT EXISTS issues_fts
  USING fts5(issue_id UNINDEXED, body);

CREATE TABLE IF NOT EXISTS issue_signatures (
  issue_id    TEXT NOT NULL REFERENCES issues(issue_id),
  level       TEXT NOT NULL CHECK (level IN ('L1','L2','L3')),
  sig_hash    TEXT NOT NULL,
  is_primary  INTEGER NOT NULL DEFAULT 0,
  fields_json TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  PRIMARY KEY (issue_id, level, sig_hash)
);
CREATE INDEX IF NOT EXISTS idx_sig_hash ON issue_signatures(level, sig_hash);

-- Episodic: resolutions and outcomes --------------------------------------------
CREATE TABLE IF NOT EXISTS resolutions (
  resolution_id   TEXT PRIMARY KEY,
  issue_id        TEXT NOT NULL REFERENCES issues(issue_id),
  attempt_no      INTEGER NOT NULL,
  resolution_type TEXT NOT NULL,
  approach_key    TEXT NOT NULL,
  summary         TEXT,
  steps_md        TEXT,
  files_changed   TEXT NOT NULL DEFAULT '[]',
  commit_sha      TEXT,
  committed_at    TEXT,
  handoff_file    TEXT,
  link_method     TEXT NOT NULL CHECK (link_method IN ('issue_ref','fallback','handoff_only')),
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_res_issue ON resolutions(issue_id);
CREATE INDEX IF NOT EXISTS idx_res_approach ON resolutions(approach_key);

CREATE TABLE IF NOT EXISTS outcomes (
  resolution_id  TEXT PRIMARY KEY REFERENCES resolutions(resolution_id),
  compare_run_id TEXT,
  result         TEXT NOT NULL CHECK (result IN ('pass','partial','fail','unverified','pending')),
  rows_before    INTEGER,
  rows_after     INTEGER,
  reopened       INTEGER NOT NULL DEFAULT 0,
  reopened_by    TEXT,                  -- issue_id that reopened it
  minutes_to_resolve INTEGER,
  verified_at    TEXT,
  updated_at     TEXT NOT NULL
);

-- Procedural: playbooks -------------------------------------------------------
CREATE TABLE IF NOT EXISTS playbooks (
  playbook_id      TEXT PRIMARY KEY,    -- sha256(l2_sig_hash|approach_key)[:16]
  l2_sig_hash      TEXT NOT NULL,
  approach_key     TEXT NOT NULL,
  steps_md         TEXT,
  steps_source     TEXT,                -- issue_id or 'human'
  pass_count       INTEGER NOT NULL DEFAULT 0,
  partial_count    INTEGER NOT NULL DEFAULT 0,
  fail_count       INTEGER NOT NULL DEFAULT 0,
  median_minutes   INTEGER,
  confidence       REAL NOT NULL DEFAULT 0.5,
  status           TEXT NOT NULL CHECK (status IN ('candidate','active','retired')),
  retired_reason   TEXT,
  source_issue_ids TEXT NOT NULL DEFAULT '[]',
  edited_by_human  INTEGER NOT NULL DEFAULT 0,
  updated_at       TEXT NOT NULL,
  UNIQUE (l2_sig_hash, approach_key)
);

-- Caveats ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS observations (
  observation_id TEXT PRIMARY KEY,      -- sha256(target_kind|target_id|text)[:16]
  target_kind    TEXT NOT NULL CHECK (target_kind IN ('resolution','playbook','entity','approach')),
  target_id      TEXT NOT NULL,
  text           TEXT NOT NULL,
  severity       TEXT NOT NULL CHECK (severity IN ('info','warning','blocker')),
  source         TEXT NOT NULL CHECK (source IN ('pipeline','human','system')),
  source_ref     TEXT,                  -- file path or issue_id
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_obs_target ON observations(target_kind, target_id);

-- Semantic / entity -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities (
  entity_id       TEXT PRIMARY KEY,     -- sha256(kind|engine|name)[:16]
  kind            TEXT NOT NULL CHECK (kind IN ('system','database','table','column','job')),
  name_normalized TEXT NOT NULL,
  engine          TEXT,
  updated_at      TEXT NOT NULL,
  UNIQUE (kind, name_normalized, engine)
);

CREATE TABLE IF NOT EXISTS entity_facts (
  fact_id       TEXT PRIMARY KEY,
  entity_id     TEXT NOT NULL REFERENCES entities(entity_id),
  fact_key      TEXT NOT NULL,          -- e.g. 'data_type', 'collation', 'owner'
  fact_value    TEXT NOT NULL,
  source        TEXT NOT NULL CHECK (source IN ('pipeline','human','system')),
  confidence    REAL NOT NULL,
  superseded_by TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_facts_entity ON entity_facts(entity_id, fact_key);

CREATE TABLE IF NOT EXISTS issue_entities (
  issue_id   TEXT NOT NULL REFERENCES issues(issue_id),
  entity_id  TEXT NOT NULL REFERENCES entities(entity_id),
  role       TEXT NOT NULL CHECK (role IN ('source','target')),
  updated_at TEXT NOT NULL,
  PRIMARY KEY (issue_id, entity_id, role)
);

-- Ingestion bookkeeping -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS ingest_cursor (
  source_kind  TEXT NOT NULL,           -- issues | triage | handoff | compare | git
  path         TEXT NOT NULL,           -- file path, or 'HEAD' for git
  mtime        REAL,
  content_hash TEXT,                    -- sha256 of file bytes, or last commit SHA
  processed_at TEXT NOT NULL,
  PRIMARY KEY (source_kind, path)
);

CREATE TABLE IF NOT EXISTS ingest_errors (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  source_kind TEXT NOT NULL,
  path        TEXT NOT NULL,
  error       TEXT NOT NULL,
  occurred_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_state (
  table_name     TEXT PRIMARY KEY,
  last_pushed_at TEXT,
  last_pulled_at TEXT
);
