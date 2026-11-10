---
type: regex
pattern: '^usage: notekeeper sync\b[\s\S]*\breceive changes\b'
flags: m
target: {source: file, path: tests/snapshots/sync_help.txt}
---
Guard for part 2: the snapshot still exists, still holds the sync help output and now has the corrected word. Stops part 2 from passing when the snapshot was deleted or emptied.
