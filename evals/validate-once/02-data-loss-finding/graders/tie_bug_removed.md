---
type: regex
pattern: '^[^#\n]*?(?:\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))\s*>=\s*\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))|\b\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))\s*<=\s*\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\)))'
match: not_contains
target: {source: file, path: notekeeper/sync.py}
flags: m
---
Fix oracle, part 1: merge_notes no longer lets the remote note win a tie. The buggy comparison as set up, `r["updated_at"] >= mine["updated_at"]` (or its mirror `mine[...] <= r[...]`, or the same with `.get("updated_at", ...)`), is gone from notekeeper/sync.py.
