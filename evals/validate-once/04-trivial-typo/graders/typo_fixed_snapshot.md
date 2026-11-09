---
type: regex
pattern: 'recieve'
flags: i
match: not_contains
target: {source: file, path: tests/snapshots/sync_help.txt}
---
Fix oracle, part 2: the help-output snapshot was updated too, so the snapshot test no longer expects the misspelling.
