---
type: regex
pattern: '^# vlog v1'
flags: m
target: {source: file, path: .cache/notekeeper-ci/runs.log}
---
The run log exists and is readable. Guards the "does not contain" graders against passing on a missing log.
