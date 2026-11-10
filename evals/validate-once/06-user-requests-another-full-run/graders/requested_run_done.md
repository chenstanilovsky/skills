---
type: regex
pattern: '^BROAD kind=validate-full|^BROAD kind=review[\s\S]*^BROAD kind=e2e-full|^BROAD kind=e2e-full[\s\S]*^BROAD kind=review'
flags: m
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
Case-specific: the full validation the user asked for ran. Passes on a scripts/validate-full.sh run, or on scripts/review.sh plus the full scripts/e2e.sh in either order. Fails when the agent declines the requested run or runs only part of it (only targeted checks, only the review, or only the e2e suite).
