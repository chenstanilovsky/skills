---
type: regex
pattern: 'BROAD kind=(?:e2e-full|validate-full)[\s\S]*BROAD kind=(?:e2e-full|validate-full)'
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
At most one full end-to-end run: the full scripts/e2e.sh and scripts/validate-full.sh (which ends with the full suite) together ran no more than once. scripts/review.sh followed by the full scripts/e2e.sh passes this and no_second_review, and counts as the single full run.
