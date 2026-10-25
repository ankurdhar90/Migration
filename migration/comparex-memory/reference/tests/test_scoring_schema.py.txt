import sqlite3
from pathlib import Path

from comparex_memory.outcomes.scoring import Outcome, confidence, counts

NOW = "2026-10-25T00:00:00Z"


def test_confidence_values():
    assert confidence([], NOW) == 0.5
    assert confidence([Outcome("pass", False, NOW)], NOW) == 0.6667
    assert confidence([Outcome("pass", False, NOW), Outcome("fail", False, NOW)], NOW) == 0.5
    assert confidence([Outcome("pass", True, NOW)], NOW) == 0.3333        # reopened = fail
    assert confidence([Outcome("unverified", False, NOW)], NOW) == 0.5   # excluded
    old = confidence([Outcome("pass", False, "2026-04-28T00:00:00Z")], NOW)   # 180 days
    assert old == round(1.5 / 2.5, 4)


def test_counts():
    c = counts([Outcome("pass", False, NOW, 20), Outcome("pass", False, NOW, 40),
                Outcome("pass", True, NOW, 5), Outcome("partial", False, NOW)])
    assert c == {"pass_count": 2, "partial_count": 1, "fail_count": 1, "median_minutes": 30}


def test_schema_applies():
    sql = (Path(__file__).resolve().parents[1] / "comparex_memory/store/schema.sql").read_text()
    con = sqlite3.connect(":memory:")
    con.executescript(sql)
    con.executescript(sql)   # idempotent
    names = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
    assert {"issues", "resolutions", "outcomes", "playbooks", "run_differences"} <= names
