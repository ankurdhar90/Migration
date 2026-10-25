"""Section 8.2: classify the KIND of mismatch from sample value pairs.

Samples are used in memory only. Nothing here logs, stores or returns the values.
"""
import unicodedata
from datetime import datetime, timezone

_TRUE = {"1", "true", "t", "yes", "y"}
_FALSE = {"0", "false", "f", "no", "n"}


def _num(x):
    try:
        return float(str(x).strip())
    except (TypeError, ValueError):
        return None


def _dt(x):
    if x is None:
        return None
    s = str(x).strip()
    if not s:
        return None
    if "." in s:  # truncate fractional seconds beyond 6 digits (SQL Server gives 7)
        head, _, tail = s.partition(".")
        i = 0
        while i < len(tail) and tail[i].isdigit():
            i += 1
        digits, rest = tail[:i], tail[i:]
        s = f"{head}.{digits[:6]}{rest}" if digits else head + rest
    try:
        d = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        d = None
        for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
            try:
                d = datetime.strptime(s, fmt)
                break
            except ValueError:
                continue
        if d is None:
            return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def _both(a, b):
    return a is not None and b is not None


def null_vs_empty(a, b, rule):
    return (a is None and b is not None and str(b).strip() == "") or \
           (b is None and a is not None and str(a).strip() == "")


def trim_equal(a, b, rule):
    return _both(a, b) and str(a).strip() == str(b).strip()


def casefold_equal(a, b, rule):
    return _both(a, b) and str(a).casefold() == str(b).casefold()


def nfc_equal(a, b, rule):
    return _both(a, b) and unicodedata.normalize("NFC", str(a)) == unicodedata.normalize("NFC", str(b))


def leading_zeros_equal(a, b, rule):
    if not _both(a, b):
        return False
    a, b = str(a).strip(), str(b).strip()
    return a.isdigit() and b.isdigit() and a.lstrip("0") == b.lstrip("0")


def boolean_equal(a, b, rule):
    if not _both(a, b):
        return False
    a, b = str(a).strip().lower(), str(b).strip().lower()
    va = True if a in _TRUE else False if a in _FALSE else None
    vb = True if b in _TRUE else False if b in _FALSE else None
    return va is not None and va == vb


def datetime_whole_hours(a, b, rule):
    da, db = _dt(a), _dt(b)
    if da is None or db is None:
        return False
    diff = abs((da - db).total_seconds())
    return diff > 0 and diff % 3600 == 0 and diff <= 14 * 3600


def datetime_subsecond(a, b, rule):
    da, db = _dt(a), _dt(b)
    if da is None or db is None:
        return False
    diff = abs((da - db).total_seconds())
    return 0 < diff < 1


def numeric_close(a, b, rule):
    na, nb = _num(a), _num(b)
    if na is None or nb is None:
        return False
    tol = float(rule.get("tolerance", 0.0001))
    d = abs(na - nb)
    return 0 < d <= tol * max(1.0, abs(na))


RULE_KINDS = {
    "null_vs_empty": null_vs_empty,
    "trim_equal": trim_equal,
    "casefold_equal": casefold_equal,
    "nfc_equal": nfc_equal,
    "leading_zeros_equal": leading_zeros_equal,
    "boolean_equal": boolean_equal,
    "datetime_whole_hours": datetime_whole_hours,
    "datetime_subsecond": datetime_subsecond,
    "numeric_close": numeric_close,
}


def classify(samples, vp_cfg: dict):
    """vp_cfg is cfg['value_patterns'] -> {min_share, rules: [...], fallback}."""
    samples = list(samples or [])
    if not samples:
        return None
    min_share = float(vp_cfg.get("min_share", 0.6))
    for rule in vp_cfg.get("rules", []):
        fn = RULE_KINDS[rule["kind"]]
        hits = sum(1 for a, b in samples if a != b and fn(a, b, rule))
        if hits / len(samples) >= min_share:
            return rule["name"]
    return vp_cfg.get("fallback", "other")
