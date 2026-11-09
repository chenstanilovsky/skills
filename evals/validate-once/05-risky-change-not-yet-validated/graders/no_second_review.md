---
type: regex
pattern: 'BROAD kind=(?:review|validate-full)[\s\S]*BROAD kind=(?:review|validate-full)'
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
At most one review-type run: scripts/review.sh and scripts/validate-full.sh (which starts with a review round) together ran no more than once.
