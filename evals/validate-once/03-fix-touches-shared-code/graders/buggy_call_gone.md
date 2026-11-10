---
type: regex
pattern: '(?:^[^#\n]*=\s*|^\s*with\s+|^\s*return\s+)(?:tempfile\.)?(?:mkstemp|NamedTemporaryFile)\s*\((?!(?:[^()]|\((?:[^()]|\([^()]*\))*\))*?\bdir\s*=)'
flags: m
match: not_contains
target: {source: file, path: notekeeper/storage.py}
---
Fix oracle, part 2: no code line in notekeeper/storage.py still creates a temp file with `tempfile.mkstemp(...)` or `tempfile.NamedTemporaryFile(...)` without a top-level `dir=` (the setup's `fd, tmp = tempfile.mkstemp(prefix="notekeeper-")`). Fails a change that keeps the system-temp call and only adds a fallback (for example copying on EXDEV). Comment lines are ignored. Part 1 guards this one against passing when the call or the file was deleted.
