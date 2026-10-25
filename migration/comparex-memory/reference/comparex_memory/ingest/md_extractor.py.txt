"""Section 9.2: config-driven Markdown field extraction. Never raises on missing fields."""
import re
from dataclasses import dataclass, field

try:
    import yaml
except ImportError:  # front matter support degrades gracefully
    yaml = None

_HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


@dataclass
class MdDoc:
    text: str
    frontmatter: dict = field(default_factory=dict)
    lines: list = field(default_factory=list)
    headings: list = field(default_factory=list)   # (line_index, level, title)


def parse_markdown(text: str) -> MdDoc:
    fm = {}
    body = text
    if text.startswith("---"):
        parts = text.split("\n")
        for i in range(1, len(parts)):
            if parts[i].strip() == "---":
                raw = "\n".join(parts[1:i])
                body = "\n".join(parts[i + 1:])
                if yaml is not None:
                    try:
                        loaded = yaml.safe_load(raw) or {}
                        if isinstance(loaded, dict):
                            fm = {str(k).lower(): v for k, v in loaded.items()}
                    except yaml.YAMLError:
                        fm = {}
                break
    lines = body.split("\n")
    headings = []
    in_code = False
    for i, line in enumerate(lines):
        if line.strip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = _HEADING.match(line)
        if m:
            headings.append((i, len(m.group(1)), m.group(2).strip()))
    return MdDoc(text=text, frontmatter=fm, lines=lines, headings=headings)


def _clean(v: str) -> str:
    v = v.strip()
    for wrap in ("**", "__", "`"):
        if v.startswith(wrap) and v.endswith(wrap) and len(v) > 2 * len(wrap):
            v = v[len(wrap):-len(wrap)].strip()
    return v


def _by_frontmatter(doc, key):
    v = doc.frontmatter.get(str(key).lower())
    return None if v is None or str(v).strip() == "" else str(v).strip()


def _by_label(doc, label):
    pat = re.compile(
        r"^\s*(?:[-*]\s+)?(?:\*\*|__)?" + re.escape(label) +
        r"(?:\*\*|__)?\s*:\s*(?:\*\*|__)?\s*(.+?)\s*$", re.IGNORECASE)
    for line in doc.lines:
        m = pat.match(line)
        if m:
            v = _clean(m.group(1))
            if v:
                return v
    return None


def _by_section(doc, names):
    wanted = {n.strip().rstrip(":").lower() for n in ([names] if isinstance(names, str) else names)}
    for idx, (line_i, level, title) in enumerate(doc.headings):
        if title.rstrip(":").strip().lower() in wanted:
            end = len(doc.lines)
            for (j, lvl, _) in doc.headings[idx + 1:]:
                if lvl <= level:
                    end = j
                    break
            v = "\n".join(doc.lines[line_i + 1:end]).strip()
            return v or None
    return None


def _by_heading(doc, level):
    for (_, lvl, title) in doc.headings:
        if lvl == int(level):
            return title or None
    return None


def _by_table(doc, key):
    k = str(key).strip().lower()
    for line in doc.lines:
        s = line.strip()
        if not (s.startswith("|") and s.endswith("|")):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if len(cells) >= 2 and _clean(cells[0]).lower() == k:
            v = _clean(cells[1])
            if v and not set(v) <= set("-: "):
                return v
    return None


_LOCATORS = {
    "frontmatter": _by_frontmatter,
    "label": _by_label,
    "section": _by_section,
    "heading": _by_heading,
    "table": _by_table,
}


def extract_fields(doc: MdDoc, locators: dict) -> dict:
    """locators: {field: [{kind: arg}, ...]} as in memory_config.yaml 'fields'."""
    out = {}
    for name, options in (locators or {}).items():
        value = None
        for loc in (options if isinstance(options, list) else [options]):
            for kind, arg in loc.items():
                fn = _LOCATORS.get(kind)
                if fn is None:
                    continue
                try:
                    value = fn(doc, arg)
                except Exception:   # a bad locator never breaks ingestion
                    value = None
                if value:
                    break
            if value:
                break
        out[name] = value
    return out


def bullets(section_text) -> list:
    """Top-level bullet items, used for observations."""
    items = []
    for line in (section_text or "").split("\n"):
        m = re.match(r"^[-*+]\s+(.*\S)\s*$", line)
        if m:
            items.append(m.group(1))
    return items


SEVERITY_TAG = re.compile(r"^\[(blocker|warning|info)\]\s*", re.IGNORECASE)


def observation_severity(item: str, default="warning"):
    """'[blocker] text' -> ('blocker', 'text')."""
    m = SEVERITY_TAG.match(item)
    if m:
        return m.group(1).lower(), item[m.end():].strip()
    return default, item.strip()
