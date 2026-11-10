---
type: regex
pattern: '^CHECK result=fail[^\n]*target=modified$(?![\s\S]*^(?:CHECK result=pass|TESTRUN\b|SCENARIO name=\S+ result=pass|[^\n]*target=original$))'
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
Case-specific: the run did not stop with the unit tests failing on changed code. A failed scripts/check.sh on modified code must be followed by a later passing check or a direct unit-test run. Passes when no check failed or nothing was changed.
