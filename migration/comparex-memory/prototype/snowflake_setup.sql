-- Long-term, shared agent memory in Snowflake
-- (If you created AGENT_MEMORY from the previous version, drop it first or
--  ALTER TABLE ... ADD COLUMN SCOPE, SCOPE_ID, SESSION_ID.)

CREATE TABLE IF NOT EXISTS AGENT_MEMORY (
  ID            STRING PRIMARY KEY,
  USER_ID       STRING NOT NULL,      -- creator
  AGENT_ID      STRING,
  SCOPE         STRING NOT NULL,      -- user | team | org
  SCOPE_ID      STRING NOT NULL,      -- user id, team id, or 'org'
  KIND          STRING NOT NULL,      -- fact | preference | episode | procedure
  MEM_KEY       STRING,
  CONTENT       STRING NOT NULL,
  SOURCE        STRING NOT NULL,      -- user | agent | tool | system
  CONFIDENCE    FLOAT,
  PINNED        BOOLEAN,
  SESSION_ID    STRING,
  CREATED_AT    TIMESTAMP_NTZ,
  UPDATED_AT    TIMESTAMP_NTZ,
  SUPERSEDED_BY STRING
);

-- Finished sessions (audit trail; working state stays local in SQLite)
CREATE TABLE IF NOT EXISTS AGENT_SESSIONS (
  ID          STRING PRIMARY KEY,
  USER_ID     STRING NOT NULL,
  AGENT_ID    STRING NOT NULL,
  GOAL        STRING,
  STATUS      STRING,                 -- completed | failed | abandoned
  OUTCOME     STRING,
  SUMMARY     STRING,
  STARTED_AT  TIMESTAMP_NTZ,
  ENDED_AT    TIMESTAMP_NTZ
);

-- Nightly decay: agent-inferred memories nobody has touched lose confidence
CREATE OR REPLACE TASK AGENT_MEMORY_DECAY
  WAREHOUSE = YOUR_WAREHOUSE
  SCHEDULE  = 'USING CRON 0 2 * * * UTC'
AS
  UPDATE AGENT_MEMORY
  SET CONFIDENCE = CONFIDENCE * 0.9
  WHERE SOURCE = 'agent' AND PINNED = FALSE AND SUPERSEDED_BY IS NULL
    AND UPDATED_AT < DATEADD(day, -30, CURRENT_TIMESTAMP());

-- Weekly cleanup: retire very low-confidence agent guesses
CREATE OR REPLACE TASK AGENT_MEMORY_CLEANUP
  WAREHOUSE = YOUR_WAREHOUSE
  SCHEDULE  = 'USING CRON 0 3 * * 0 UTC'
AS
  UPDATE AGENT_MEMORY SET SUPERSEDED_BY = 'expired'
  WHERE SOURCE = 'agent' AND CONFIDENCE < 0.2 AND SUPERSEDED_BY IS NULL;

ALTER TASK AGENT_MEMORY_DECAY RESUME;
ALTER TASK AGENT_MEMORY_CLEANUP RESUME;

-- Optional: let people query only memories they are allowed to see.
-- Replace TEAM_MEMBERSHIP with your own user/team mapping table.
-- CREATE OR REPLACE ROW ACCESS POLICY AGENT_MEMORY_RAP AS (scope STRING, scope_id STRING)
-- RETURNS BOOLEAN ->
--   scope = 'org'
--   OR (scope = 'user' AND scope_id = CURRENT_USER())
--   OR (scope = 'team' AND EXISTS (SELECT 1 FROM TEAM_MEMBERSHIP tm
--        WHERE tm.TEAM_ID = scope_id AND tm.USER_NAME = CURRENT_USER()))
--   OR IS_ROLE_IN_SESSION('AGENT_MEMORY_ADMIN');
-- ALTER TABLE AGENT_MEMORY ADD ROW ACCESS POLICY AGENT_MEMORY_RAP ON (SCOPE, SCOPE_ID);

-- Handy queries
-- What does the system believe about a user (incl. shared)?
-- SELECT SCOPE, SCOPE_ID, KIND, CONTENT, SOURCE, CONFIDENCE, UPDATED_AT
-- FROM AGENT_MEMORY WHERE SUPERSEDED_BY IS NULL
--   AND (SCOPE='org' OR SCOPE_ID IN ('alice', 'data-eng'))
-- ORDER BY SCOPE, KIND, UPDATED_AT DESC;
--
-- Which tasks keep failing?
-- SELECT AGENT_ID, GOAL, COUNT(*) FROM AGENT_SESSIONS
-- WHERE STATUS = 'failed' GROUP BY 1, 2 ORDER BY 3 DESC;
