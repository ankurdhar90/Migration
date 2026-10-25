# Phase 3a (config fitting)

Paste the block below into Amp.

```text
Read migration/comparex-memory/docs/IMPLEMENTATION_GUIDE.md sections 5 and 9.1. Do not write any Python yet.
Follow migration/comparex-memory/docs/ALIGNMENT.md: reuse the existing code it names, use its layout and
names instead of the defaults below, and adapt anything that conflicts with the existing
build while keeping the invariants in section 0.1.

1. Find 5 recent examples each of: issue MD files, triage MD files, handoff MD files, and
   Comparex result files. Also run `git log -20 --format='%H %s'` and look at how commits and
   branches refer to issues.
2. Update memory_config.yaml so that:
   - paths globs match where these files actually live,
   - issue_id_pattern and git.issue_ref_pattern match the real ID format,
   - every entry under fields points at the real headings / labels / front matter keys,
   - resolution_rules match the real folders where fixes are committed (compare configs,
     SQL views, transforms, etc.),
   - type_map covers every data type you see in the result files.
3. Write migration/comparex-memory/docs/FORMAT_NOTES.md describing each file format you found, with one
   anonymized example per format (replace table names, values and people with placeholders;
   never copy real data values).
4. List anything that does not fit the locator kinds in section 5 (frontmatter, label,
   section, heading, table) so we can decide whether to add a locator kind.

Do not modify any of the files you inspected.
```
