import hashlib


def stable_id(*parts) -> str:
    """Deterministic 16-hex-char ID so re-ingesting never creates duplicates."""
    norm = ["" if p is None else str(p) for p in parts]
    return hashlib.sha256("|".join(norm).encode("utf-8")).hexdigest()[:16]
