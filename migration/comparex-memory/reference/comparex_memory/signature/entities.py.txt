"""Section 8.4, name normalization. DB upserts depend on the DB layer chosen in Phase 0."""
import re


def normalize_object(name):
    if name is None:
        return None
    s = str(name).replace("[", "").replace("]", "").replace('"', "").replace("`", "")
    s = re.sub(r"\s+", " ", s).strip().lower()
    return ".".join(part.strip() for part in s.split("."))


def split_object(name):
    """Returns (database, full_name). 'a.b.c' -> ('a', 'a.b.c'); 'b.c' -> (None, 'b.c')."""
    n = normalize_object(name)
    parts = n.split(".") if n else []
    return (parts[0] if len(parts) >= 3 else None), n
