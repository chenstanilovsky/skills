---
type: regex
pattern: '^(CHECK result=pass|SCENARIO name=\S+ result=pass|TESTRUN).*target=modified'
flags: m
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
At least one fast or targeted check ran after the code was changed.
