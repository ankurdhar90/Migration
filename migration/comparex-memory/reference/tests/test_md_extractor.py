from comparex_memory.ingest.md_extractor import (parse_markdown, extract_fields, bullets,
                                                 observation_severity)

DOC = """---
category: data-type
Created: 2026-09-01T10:00:00Z
---
# ISSUE-123 Timestamp precision mismatch

**Severity:** High
- Source table: [Sales].[dbo].[Orders]

| Field | Value |
| --- | --- |
| Target | SALES.PUBLIC.ORDERS |

## Description
Precision differs.

## Notes
- [blocker] Do not change source precision
- Normalization hides drift

```
# not a heading
```
## Other
x
"""


def test_locators():
    doc = parse_markdown(DOC)
    f = extract_fields(doc, {
        "title": [{"heading": 1}],
        "category": [{"label": "Category"}, {"frontmatter": "category"}],
        "created": [{"frontmatter": "created"}],
        "severity": [{"label": "Severity"}],
        "source": [{"label": "Source table"}],
        "target": [{"table": "Target"}],
        "description": [{"section": ["Description"]}],
        "missing": [{"label": "Nope"}, {"section": ["Nope"]}],
    })
    assert f["title"] == "ISSUE-123 Timestamp precision mismatch"
    assert f["category"] == "data-type"
    assert f["created"]  # yaml may parse as datetime; string form is fine
    assert f["severity"] == "High"
    assert f["source"] == "[Sales].[dbo].[Orders]"
    assert f["target"] == "SALES.PUBLIC.ORDERS"
    assert f["description"] == "Precision differs."
    assert f["missing"] is None


def test_observations():
    doc = parse_markdown(DOC)
    notes = extract_fields(doc, {"n": [{"section": "Notes"}]})["n"]
    items = bullets(notes)
    assert [observation_severity(i) for i in items] == [
        ("blocker", "Do not change source precision"),
        ("warning", "Normalization hides drift"),
    ]


def test_code_block_heading_ignored():
    doc = parse_markdown(DOC)
    assert all("not a heading" not in h[2] for h in doc.headings)
