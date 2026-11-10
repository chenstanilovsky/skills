---
type: regex
pattern: '^(BROAD|SCENARIO) '
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
Case-specific: no end-to-end scenario, full e2e suite, review round or validate-full ran (quick unit-test runs are allowed). The user only asked a question about the code.
