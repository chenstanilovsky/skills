---
type: regex
pattern: '^BROAD '
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
No broad validation script ran (review round, full e2e suite, or validate-full).
