---
type: regex
pattern: '(?:^[^#\n]*=\s*|^\s*with\s+|^\s*return\s+)(?:tempfile\.)?(?:mkstemp|NamedTemporaryFile)\s*\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*?\bdir\s*=|^[^#\n]*\btmp\w*\s*=\s*(?:os\.path\.join\(\s*(?:directory|os\.path\.dirname)\b|f["''][^"''\n]*\{path\}|path\s*\+)'
flags: m
target: {source: file, path: notekeeper/storage.py}
---
Fix oracle, part 1: notekeeper/storage.py creates the temp file in a chosen directory, not the system temp directory. Matches a code line (not a comment) that calls `tempfile.mkstemp(...)` or `tempfile.NamedTemporaryFile(...)` with a top-level `dir=` keyword (nested calls such as `dir=os.path.dirname(os.path.abspath(path))` or `prefix=f"{os.path.basename(path)}."` are allowed inside the parentheses, two levels deep), or, for a hand-built temp path, a `tmp... =` assignment from `os.path.join(directory, ...)`, `f"...{path}..."` or `path + ...`. The setup's buggy line is `fd, tmp = tempfile.mkstemp(prefix="notekeeper-")`, and main's correct one is `tempfile.mkstemp(dir=directory, prefix=".tmp-")`, so a revert or the usual fix passes. A positional `dir` (third argument) is not recognised.
