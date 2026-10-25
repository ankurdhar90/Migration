"""Section 8.1: parse engine data types into families. Pure functions."""
import logging
import re
from dataclasses import dataclass

log = logging.getLogger(__name__)
_TYPE_RE = re.compile(r"^\s*([a-z_][a-z0-9_ ]*?)\s*(?:\(\s*([^)]*)\s*\))?\s*$")
_warned: set = set()


@dataclass(frozen=True)
class TypeInfo:
    raw: str
    base: str
    params: tuple
    family: str
    full: str


def parse_type(raw, engine: str, type_map: dict):
    """type_map is cfg['type_map'] -> {engine: {base: family}}."""
    if raw is None or not str(raw).strip():
        return None
    text = str(raw).strip().lower()
    m = _TYPE_RE.match(text)
    if not m:
        return TypeInfo(str(raw), text, (), "unknown", text)
    base = " ".join(m.group(1).split())
    params_raw = m.group(2)
    params = ()
    full = base
    if params_raw is not None:
        parts = [p.strip() for p in params_raw.split(",") if p.strip()]
        if parts and all(p.isdigit() for p in parts):
            params = tuple(int(p) for p in parts)
        full = f"{base}({','.join(parts)})"      # e.g. datetime2(7), varchar(max)
    family = type_map.get(engine, {}).get(base)
    if family is None:
        family = "unknown"
        if (engine, base) not in _warned:
            _warned.add((engine, base))
            log.info("Unknown type %r for engine %r; add it to type_map", base, engine)
    return TypeInfo(str(raw), base, params, family, full)
