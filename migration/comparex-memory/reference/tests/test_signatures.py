from comparex_memory.signature.hashing import H, Signature, normalize_category, primary
from comparex_memory.signature.type_map import parse_type
from comparex_memory.signature.value_patterns import classify, RULE_KINDS
from comparex_memory.signature.entities import normalize_object, split_object


def test_parse_type(cfg):
    tm = cfg["type_map"]
    t = parse_type("DATETIME2(7)", "sqlserver", tm)
    assert (t.base, t.params, t.family, t.full) == ("datetime2", (7,), "datetime", "datetime2(7)")
    t = parse_type("NUMBER(38,0)", "snowflake", tm)
    assert (t.params, t.family, t.full) == ((38, 0), "decimal", "number(38,0)")
    t = parse_type("varchar(max)", "sqlserver", tm)
    assert (t.params, t.family, t.full) == ((), "string", "varchar(max)")
    assert parse_type("TIMESTAMP_NTZ(9)", "snowflake", tm).family == "datetime"
    assert parse_type("geography", "snowflake", tm).family == "unknown"
    assert parse_type(None, "snowflake", tm) is None


def _r(kind, **kw):
    return dict(kind=kind, **kw)


def test_rules_positive_and_negative():
    cases = [
        ("null_vs_empty", (None, ""), (None, "x")),
        ("trim_equal", ("abc  ", "abc"), ("abc", "abd")),
        ("casefold_equal", ("ABC", "abc"), ("abc", "abd")),
        ("nfc_equal", ("e\u0301", "\u00e9"), ("e", "f")),
        ("leading_zeros_equal", ("007", "7"), ("007", "8")),
        ("boolean_equal", ("1", "true"), ("1", "false")),
        ("datetime_whole_hours", ("2026-01-01 10:00:00", "2026-01-01 05:00:00"),
         ("2026-01-01 10:00:00", "2026-01-01 10:30:00")),
        ("datetime_subsecond", ("2026-08-01 10:00:00.1234567", "2026-08-01 10:00:00.123"),
         ("2026-08-01 10:00:00", "2026-08-01 10:00:05")),
        ("numeric_close", ("10.00001", "10.00002"), ("10", "11")),
    ]
    for kind, pos, neg in cases:
        fn = RULE_KINDS[kind]
        rule = _r(kind, tolerance=0.0001)
        assert fn(*pos, rule), kind
        assert not fn(*neg, rule), kind


def test_classify(cfg):
    vp = cfg["value_patterns"]
    assert classify([], vp) is None
    assert classify([("a ", "a"), ("b  ", "b"), ("c", "d")], vp) == "trailing_whitespace"
    assert classify([("a", "b"), ("c", "d")], vp) == "other"
    # order matters: equal values never count as a match
    assert classify([("x", "x"), ("x", "x")], vp) == "other"


def test_golden_hashes(cfg):
    tm = cfg["type_map"]
    s = Signature("sqlserver->snowflake", "value_mismatch", "sales.dbo.orders",
                  "sales.public.orders", "created_at",
                  parse_type("DATETIME2(7)", "sqlserver", tm),
                  parse_type("TIMESTAMP_NTZ(9)", "snowflake", tm), "fractional_seconds")
    # Frozen values: if these change, hashing changed and all stored memory is invalidated.
    assert s.l1() == H("L1", "sqlserver->snowflake", "value_mismatch", "datetime2(7)",
                       "timestamp_ntz(9)", "sales.dbo.orders>sales.public.orders", "created_at")
    assert s.l1() == "L1:" + GOLDEN["L1"]
    assert s.l2() == "L2:" + GOLDEN["L2"]
    assert s.l3() == "L3:" + GOLDEN["L3"]
    s2 = Signature(**{**s.__dict__, "column_ref": "updated_at"})
    assert s2.l1() != s.l1() and s2.l3() != s.l3() and s2.l2() == s.l2()
    assert s.human() == "sqlserver->snowflake | value_mismatch | datetime->datetime | fractional_seconds"


def test_fields_have_no_values(cfg):
    tm = cfg["type_map"]
    s = Signature("a->b", "value_mismatch", "x", "y", "c",
                  parse_type("int", "sqlserver", tm), None, "other")
    assert set(s.fields()) == {"engine_pair", "diff_category", "source_object", "target_object",
                               "column_ref", "source_type", "target_type", "type_family_pair",
                               "value_pattern"}


def test_misc():
    assert normalize_category("Value Mismatch") == "value_mismatch"
    assert normalize_category("weird") == "other"
    assert primary([("b", 10), ("a", 10), ("c", 5)])[0] == "a"
    assert normalize_object("[Sales].[dbo].[Orders]") == "sales.dbo.orders"
    assert split_object("dbo.orders") == (None, "dbo.orders")


GOLDEN = {'L1': 'ba245aadeabe22a2', 'L2': '00d4db6439d09b3a', 'L3': '7a954ad9d3850721'}
