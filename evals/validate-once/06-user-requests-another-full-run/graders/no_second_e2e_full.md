---
type: regex
pattern: 'BROAD kind=(?:e2e-full|validate-full)[\s\S]*BROAD kind=(?:e2e-full|validate-full)'
flags: m
match: not_contains
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
Case-specific: at most one run of the full end-to-end suite (scripts/e2e.sh with no scenario, or scripts/validate-full.sh, which includes it). Single scenarios (scripts/e2e.sh --scenario) don't count.
