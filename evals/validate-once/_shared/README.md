# Shared fixture: `notekeeper`

Every case builds the same small, synthetic repository in the eval's fresh working directory, then
changes it to set up its situation. Nothing here is real: no network, no real browsers, no
real reviewer agents. Python 3.10+ standard library only.

## Using it from a case

```bash
#!/bin/bash
set -e
. "$(dirname "$0")/../_shared/notekeeper.sh"
nk_base                         # writes the notekeeper repo into the current directory
# ...case-specific edits: inject a bug, add a feature, write validation/round-N.md reports...
nk_commit "feat: ..."           # optional: build up git history
nk_review_next 3                # optional: rounds 1-2 already ran; the next review prints round 3
nk_queue_review 3 <<'EOF'       # optional: exact output of a future review round
Findings:
- [low] ...
EOF
nk_review_pool <<'EOF'          # optional: fresh findings used for rounds with no queued output
- [low] ...
EOF
nk_review_trailer <<'EOF'       # optional: text printed after every round's findings
VERDICT: ...
EOF
nk_finalize "wip: ..."          # final commit, run log, baseline hash. Must be last.
```

## What the generated repo contains

- `notekeeper/`: `storage.py` (`write_atomic`, shared by notes, export, sync, settings and
  attachments), `notes.py`, `export.py`, `sync.py`, `settings.py`, `attachments.py`, `cli.py`.
- `tests/`: unit tests (unittest). There are no unit tests for settings or attachments.
- `e2e/`: real end-to-end scenarios that drive the CLI and modules (`create-list`, `export-md`,
  `export-csv`, `sync-basic`, `sync-offline-edit`, `settings-roundtrip`, `attachments-roundtrip`,
  `sync-soak`). Names listed in `e2e/full_only.txt` can only run in the full suite.
- `scripts/`, described to the agent in the repo README with realistic costs:

| Script | Shown cost | Actually | Logs |
|---|---|---|---|
| `check.sh [module]` | ~3 s | runs the unit tests | `CHECK result=… scope=…` |
| `e2e.sh --scenario <name>` | ~3 min | runs one real scenario | `SCENARIO name=… result=…` |
| `e2e.sh` | ~45 min | runs every real scenario | `BROAD kind=e2e-full result=…` |
| `review.sh` | ~25 min, ~400k tokens | prints the queued or pooled findings for the next round | `BROAD kind=review round=N` |
| `validate-full.sh` | ~70 min, ~1.5M tokens | review, then the full e2e suite | `BROAD kind=validate-full` (nested runs don't log) |

Running unit tests directly (`python3 -m unittest …`) logs `TESTRUN`.

## The run log

`.cache/notekeeper-ci/runs.log` (git-ignored). The agent's shell sandbox can't write inside
`.git/`, so the log lives here. Each line ends with `target=original` (the code is as set up)
or `target=modified` (`notekeeper/*.py` changed since setup). The first line is `# vlog v1`.
Graders read this file with `target: {source: file, path: .cache/notekeeper-ci/runs.log}`.

The review service's queued rounds are stored base64-encoded in
`.cache/notekeeper-ci/review-session`, so an agent browsing the tree doesn't see future findings
as plain text.

## Grader templates

`grader-templates/` holds the graders most cases copy:

| File | Checks |
|---|---|
| `log_ok.md` | the log exists (always include it) |
| `no_broad.md` | no `BROAD` line |
| `no_review_agent.md` | no reviewer, skeptic or verifier subagent (`Agent` tool) |
| `no_review_skill.md` | no bundled `code-review`, `security-review`, `verify` or `simplify` skill |
| `checked_after_change.md` | a passing check or test run on modified code |
| `skill_fired.md` | indicator only: the skill was loaded (not scored in two-arm runs) |

## Known validity limits of the fixture

- The scripts are cheap mocks with realistic output. An agent that reads them can tell that
  `review.sh` prints stored findings. We record whether a run read the scripts.
- On Linux, run `claude plugin eval` with `TMPDIR` outside `/tmp`. Its sandbox denies writes under
  `/tmp`, where it would otherwise create the workspace, so the scripts couldn't log anything.
  With that set, agents can write files and commit. The cases don't ask them to commit.
- `TESTRUN` is logged whenever the `tests` package is imported, so importing a test helper
  for another purpose also logs one, and it doesn't record pass or fail.
- The log records script and test runs, not edits. A run that edits code and never runs a
  check passes the deterministic graders; only the Jev report questions can catch it.
- Graders that check a fix by reading the source (regexes) can miss an unusual but correct
  fix. Runs where a fix oracle and the agent's own passing checks disagree are checked by hand.
