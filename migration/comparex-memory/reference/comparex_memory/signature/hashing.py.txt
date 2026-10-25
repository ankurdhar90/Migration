"""Section 8.3: L1/L2/L3 signatures. Pure functions; no sample values anywhere."""
import hashlib
from dataclasses import dataclass

STANDARD_CATEGORIES = {
    "value_mismatch", "type_mismatch", "missing_column", "extra_column", "row_count",
    "missing_rows", "extra_rows", "null_handling", "nullability_mismatch",
    "length_mismatch", "precision_scale", "collation", "duplicate_keys", "other",
}


def H(level: str, *parts) -> str:
    norm = ["-" if p is None else str(p).strip().lower() for p in parts]
    return f"{level}:" + hashlib.sha256("|".join(norm).encode("utf-8")).hexdigest()[:16]


def _full(t):
    return None if t is None else t.full


def _fam(t):
    return "-" if t is None else t.family


@dataclass(frozen=True)
class Signature:
    engine_pair: str
    diff_category: str
    source_object: str
    target_object: str
    column_ref: object       # str | None
    source_type: object      # TypeInfo | None
    target_type: object      # TypeInfo | None
    value_pattern: object    # str | None

    def l1(self):
        return H("L1", self.engine_pair, self.diff_category, _full(self.source_type),
                 _full(self.target_type), f"{self.source_object}>{self.target_object}",
                 self.column_ref)

    def l2(self):
        return H("L2", self.engine_pair, self.diff_category,
                 f"{_fam(self.source_type)}->{_fam(self.target_type)}", self.value_pattern)

    def l3(self):
        return H("L3", self.source_object, self.target_object, self.column_ref)

    def fields(self) -> dict:
        return {
            "engine_pair": self.engine_pair,
            "diff_category": self.diff_category,
            "source_object": self.source_object,
            "target_object": self.target_object,
            "column_ref": self.column_ref,
            "source_type": _full(self.source_type),
            "target_type": _full(self.target_type),
            "type_family_pair": f"{_fam(self.source_type)}->{_fam(self.target_type)}",
            "value_pattern": self.value_pattern,
        }

    def human(self) -> str:
        return " | ".join([self.engine_pair, self.diff_category,
                           f"{_fam(self.source_type)}->{_fam(self.target_type)}",
                           self.value_pattern or "-"])


def normalize_category(raw) -> str:
    c = (raw or "").strip().lower().replace(" ", "_").replace("-", "_")
    return c if c in STANDARD_CATEGORIES else "other"


def primary(diffs):
    """diffs: list of (diff_key, rows_affected, ...). Most rows wins; ties by diff_key."""
    return sorted(diffs, key=lambda d: (-int(d[1] or 0), d[0]))[0] if diffs else None
