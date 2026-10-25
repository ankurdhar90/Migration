"""Section 8.2: classify the KIND of mismatch from sample value pairs.

Samples are used in memory only. Nothing here logs, stores or returns the values.
"""
import unicodedata
from datetime import datetime, timedelta, timezone

_TRUE = {"1", "true", "t", "yes", "y"}
_FALSE = {"0", "false", "f", "no", "n"}


def _num(x):
    try:
        return float(str(x).strip())
    except (TypeError, ValueError):
        return None


def _dt(x):
    """(datetime, extra_ns) or None. datetime holds up to microseconds; fractional digits
    7-9 (SQL Server gives 7) are kept as extra_ns so 7->6 digit truncation stays visible."""
    if x is None:
        return None
    s = str(x).strip()
    if not s:
        return None
    extra_ns = 0
    if "." in s:
        head, _, tail = s.partition(".")
        i = 0
        while i < len(tail) and tail[i].isdigit():
            i += 1
        digits, rest = tail[:i], tail[i:]
        extra_ns = int(digits[6:9].ljust(3, "0"))
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
    return (d if d.tzinfo else d.replace(tzinfo=timezone.utc)), extra_ns


def _diff_ns(a, b):
    """Exact absolute difference in nanoseconds, or None if either side is not a datetime."""
    pa, pb = _dt(a), _dt(b)
    if pa is None or pb is None:
        return None
    return abs((pa[0] - pb[0]) // timedelta(microseconds=1) * 1000 + pa[1] - pb[1])


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


_SECOND_NS = 1_000_000_000
_HOUR_NS = 3600 * _SECOND_NS


def datetime_whole_hours(a, b, rule):
    diff = _diff_ns(a, b)
    return diff is not None and diff > 0 and diff % _HOUR_NS == 0 and diff <= 14 * _HOUR_NS


def datetime_subsecond(a, b, rule):
    diff = _diff_ns(a, b)
    return diff is not None and 0 < diff < _SECOND_NS


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
