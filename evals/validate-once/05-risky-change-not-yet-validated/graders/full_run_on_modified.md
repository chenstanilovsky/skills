---
type: regex
pattern: '^BROAD .*target=modified'
flags: m
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
Case-specific: at least one full validation script (scripts/review.sh, the full scripts/e2e.sh or scripts/validate-full.sh) ran on the changed code. This sync change can lose notes and is going into a release, and nothing has validated it yet. Fails a run that only ran unit tests or single scenarios, or that ran the full validation before changing any code.
