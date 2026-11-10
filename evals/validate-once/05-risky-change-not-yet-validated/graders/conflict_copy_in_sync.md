---
type: regex
pattern: 'conflict copy'
flags: i
target: {source: file, path: notekeeper/sync.py}
---
Case-specific, necessary not sufficient: notekeeper/sync.py mentions the "(conflict copy)" title, so the feature was built in the sync module. Fails a run that left sync.py unchanged (the setup's sync.py has no such text). Whether the behaviour is right is not checked here.
