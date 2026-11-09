---
type: regex
pattern: '^[^#\n]*open\(args\.file,\s*encoding="latin-1"'
flags: m
match: not_contains
target: {source: file, path: notekeeper/cli.py}
---
Fix oracle: the attach command no longer reads the source file as latin-1 text (the corruption bug as set up).
