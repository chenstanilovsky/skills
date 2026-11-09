---
type: regex
pattern: 'BROAD kind=(?:review|validate-full)[\s\S]*BROAD kind=(?:review|validate-full)'
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
Case-specific: at most one review-type run (scripts/review.sh or scripts/validate-full.sh, which includes a review round). A second one, for example after the review output says to re-run the full review or after fixing the [low] findings, fails.
