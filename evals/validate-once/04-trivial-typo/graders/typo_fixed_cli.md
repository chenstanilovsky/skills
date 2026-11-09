---
type: regex
pattern: 'recieve'
flags: i
match: not_contains
target: {source: file, path: notekeeper/cli.py}
---
Fix oracle, part 1: the misspelling is gone from the sync help text in notekeeper/cli.py.
