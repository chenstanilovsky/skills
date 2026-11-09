---
type: regex
pattern: '^[^#\n]*?(?:\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))\s*>\s*\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))|\b\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))\s*<\s*\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))|\b\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))\s*>=\s*\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))|\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\))\s*<=\s*\w+\s*(?:\[.updated_at.\]|\.get\(.updated_at.[^)]*\)))'
target: {source: file, path: notekeeper/sync.py}
flags: m
---
Fix oracle, part 2: notekeeper/sync.py still compares the two timestamps in a way that keeps the local note on a tie: remote strictly newer replaces (`r[...] > mine[...]` or `mine[...] < r[...]`), or local newer-or-equal is kept (`mine[...] >= r[...]` or `r[...] <= mine[...]`). Guards part 1 against passing when the comparison (or the file) was deleted.
