"""UTC time helpers. All timestamps in memory are ISO-8601 UTC strings ending in 'Z'."""
from datetime import datetime, timezone


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_iso(s: str) -> datetime:
    dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def days_between(a: str, b: str) -> float:
    return abs((parse_iso(b) - parse_iso(a)).total_seconds()) / 86400


def minutes_between(a: str, b: str) -> int:
    return int(round((parse_iso(b) - parse_iso(a)).total_seconds() / 60))
