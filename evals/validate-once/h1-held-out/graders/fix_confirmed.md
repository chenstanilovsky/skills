---
type: regex
pattern: '^(?:SCENARIO name=attach-cli-binary result=pass|CHECK result=pass|TESTRUN)[^\n]*target=modified'
flags: m
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
A targeted check ran after the code changed: the attach-cli-binary scenario passed, or unit tests ran (check.sh pass or a direct unittest run). Whether the bug itself is gone is checked by latin1_read_gone.md.
