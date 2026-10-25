"""Section 10.2: confidence for an approach on an L2 signature."""
from dataclasses import dataclass
from statistics import median

from ..timeutil import days_between

SCORE = {"pass": 1.0, "partial": 0.5, "fail": 0.0}   # unverified / pending excluded


@dataclass(frozen=True)
class Outcome:
    result: str               # pass | partial | fail | unverified | pending
    reopened: bool
    when: str                 # verified_at or updated_at, ISO UTC
    minutes_to_resolve: object = None


def confidence(outcomes, now: str, half_life_days: float = 180.0) -> float:
    num, den = 1.0, 2.0       # Laplace prior: starts at 0.5
    for o in outcomes:
        if o.result not in SCORE:
            continue
        s = 0.0 if o.reopened else SCORE[o.result]
        w = 0.5 ** (days_between(o.when, now) / half_life_days)
        num += w * s
        den += w
    return round(num / den, 4)


def counts(outcomes):
    p = sum(1 for o in outcomes if o.result == "pass" and not o.reopened)
    pa = sum(1 for o in outcomes if o.result == "partial")
    f = sum(1 for o in outcomes if o.result == "fail" or (o.result == "pass" and o.reopened))
    mins = [o.minutes_to_resolve for o in outcomes
            if o.result == "pass" and not o.reopened and o.minutes_to_resolve is not None]
    return {"pass_count": p, "partial_count": pa, "fail_count": f,
            "median_minutes": int(median(mins)) if mins else None}
