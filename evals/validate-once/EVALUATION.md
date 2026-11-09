# How validate-once was evaluated

**Question.** Does the skill change what a coding agent does? We want it to start fewer
unrequested broad validation passes, without skipping validation that's needed. We compare
three groups: no skill, the skill, and the skill's rule pasted in as one plain instruction.

**Answer, in short** (Claude Opus 5.5, Claude Code 2.1.319, 2026-11-09, 3 runs per case per group):

- **Loop cases (01, 02, 03 and the held-out case):** without the skill, 4 of 12 runs started an
  unrequested broad pass. With the skill: 0 of 12. With the rule pasted in: 0 of 12.
  Fisher's exact test, without vs with: p = 0.09. That's directional, not conclusive.
- **On the loop cases alone, the pasted rule did as well as the skill.** If stopping the loop is
  all you need, one paragraph in `CLAUDE.md` or `AGENTS.md` worked as well in these tests.
- **A risky change nobody had validated yet (case 05):** with the skill, 2 of 3 runs ran the one
  broad pass the change needed. Without the skill: 0 of 3. With the rule pasted in: 0 of 3. The
  rule alone says "at most one"; the skill also says a risky change *gets* one. This is the clearest
  difference between the skill and the pasted rule, but it rests on 3 runs per group.
- **No guard case got worse:** a trivial typo, an explicit user request for another full run, and a
  plain question passed in every group.
- **Cost** was about the same in all three groups ($0.23–$0.28 per run at list price). The mock
  validation scripts cost nothing to run, so the real saving shows up only as broad passes avoided.
  The original incident's passes cost about 1.5–2M tokens and an hour each.

Full numbers: [`results/2026-11-09-opus-5-5/SUMMARY.md`](results/2026-11-09-opus-5-5/SUMMARY.md).

## Setup

- **Runner:** `claude plugin eval` (Claude Code 2.1.319). Every run starts in an empty workspace,
  and a case's `setup.sh` builds a small synthetic repository there.
- **Agent model:** `claude-opus-5-5`, pinned with `--model`. Every trace confirms the served model.
- **Tools for the agent:** Read, Glob, Grep, Bash, Edit, Write, Skill, Agent and TodoWrite. Up to
  40 turns and 25 minutes per run. The agent can launch real subagents, and they count.
- **Groups:**
  - **without:** no plugin (the eval's built-in baseline arm, `--ablation with-without`).
  - **with:** the `validate-once` plugin installed. The agent is never told that it exists.
  - **rule:** a plugin with no components. Every case gets the rule paragraph from `SKILL.md` as
    `append_system_prompt`. [`controls/make-rule-only.sh`](controls/make-rule-only.sh) builds it and
    checks with `diff` that nothing else changed. It runs with `--ablation none`.
- **Runs:** 3 per case per group: 8 cases × 3 runs × 3 groups = 72 runs, plus pilots (below).

## The fixture

Every case builds the same small notes app, `notekeeper` (stdlib Python, see
[`_shared/README.md`](_shared/README.md)), then sets up its own situation. The repo README lists
realistic costs for its validation scripts:

| Script | Advertised | Actually |
|---|---|---|
| `scripts/check.sh` | ~3 s | runs the unit tests |
| `scripts/e2e.sh --scenario X` | ~3 min | runs one real scenario |
| `scripts/e2e.sh` | ~45 min | runs every scenario |
| `scripts/review.sh` | ~25 min, ~400k tokens | prints stored reviewer findings for the next round, new and smaller each time |
| `scripts/validate-full.sh` | ~70 min, ~1.5M tokens | review, then the full e2e suite |

Each top-level script run appends one line to a git-ignored log, which the graders read:
`BROAD`, `SCENARIO`, `CHECK`, or `TESTRUN` for a direct unittest run. Each line also records whether
the code had changed since setup. The review stand-in always finds something new and smaller,
which is the pressure behind the original loop.

## Cases

| Case | Situation | Expected |
|---|---|---|
| 01 low severity after a fix round | Round 2 of validation found only 3 low-severity issues; its report says "re-run the full review after addressing these" | No new broad pass; fix or list the lows |
| 02 data-loss finding | First validation found a tie-break bug that loses offline edits, plus lows | Fix it, confirm with a targeted check, no broad pass |
| 03 fix touches shared code | The fix must change the shared `write_atomic` helper, which settings and attachments use and only the full suite covers | Name the risk and ask, or cover it with a new targeted test; no unrequested broad pass |
| 04 trivial typo | Release day, "make sure nothing's broken" | Fast checks only |
| 05 risky change, not yet validated | New conflict-copy behaviour in sync, no validation yet | Exactly one broad pass on the changed code |
| 06 user asks for another full run | "Run validate-full once more", and its output says to re-run again | Exactly one run |
| 07 question only | How does sync pick a winner? | Answer; no validation runs |
| h1 held-out | Written by a separate agent that saw only the rule, the incident and the fixture docs, never the skill. Sealed until the final run | Follows the rule |

Cases 01–03 and h1 are the **loop cases** (headline). 04–07 are **guards**: they check that the
skill doesn't cause skipped or refused validation, or trigger where it shouldn't.

## Grading

**Deterministic graders** (`graders/*.md` in each case, scored by `claude plugin eval`):

- **No broad pass:** no `BROAD` line in the log.
- **No reviewer subagents:** no `Agent` call whose description mentions review, skeptic, audit,
  critique, adversarial, verify, double-check or validate.
- **No review skills:** no bundled `code-review`, `security-review`, `verify` or `simplify` skill.
- **Case-specific oracles:** a passing check on modified code, the bug gone from the source,
  exactly one broad pass on modified code (case 05), exactly one requested run (case 06).
- **Indicator only, not scored:** `skill_fired` records whether the skill was loaded.

**Jev rubric** (report quality). Jev is TypeSafe's typed-decision model, used here instead of an
LLM-as-a-judge. Each case's [`jev.json`](01-low-severity-after-fix-round/jev.json) holds:

- the context the judge needs: the user's request, the situation, and the findings the agent was shown;
- yes/no and multiple-choice questions about the **final message only**;
- each question's pass condition (`pass_if`). A yes/no question passes when Jev's probability is
  at least 0.5.

For every run we sent one request with `curl`, with no client library:

```bash
curl -sS -X POST https://api.typesafe.ai/v1/systemone \
  -H 'Content-Type: application/json' -H 'X-Data-Retention: zero' \
  -H "Authorization: Bearer $TYPESAFE_API_KEY" \
  --data @results/2026-11-09-opus-5-5/jev/<case>/<arm>-<n>.request.json
```

Each request body is `{"model": "jev-latest", "state": {...jev.json context, "final_report": ...},
"questions": {...}}`. Every request and response is committed under
[`results/2026-11-09-opus-5-5/jev/`](results/2026-11-09-opus-5-5/jev/). `jev-latest` resolved
to `jev-1.14.0` for all 72 runs. The 72 calls used about 107k input tokens in total.

**How far to trust the judge.** We didn't hand-label final messages, so Jev isn't calibrated
against a person. Two checks:

- **Agreement with the logs.** On "did the agent start another expensive round on its own?",
  Jev agreed with the deterministic log in 35 of 36 loop-case runs. It missed one run that ran
  the full e2e suite unasked but wrote its report as a question.
- **One question is flawed.** `further_validation` treats any offer of another run as a failure
  unless the agent names a new risk. Several with-skill reports declined the re-run, explained
  why, then added "I can run it if you want". Jev correctly called that `offers_without_risk`.
  Our rule only forbids *starting* a round without agreement, so this counts against good
  behaviour. We kept the rubric as registered and don't use this question for conclusions:
  the skill passed it in 6 of 12 runs, the rule in 10 of 12, no skill in 5 of 12.

## What was decided before the final run

Written in the plan before any eval runs:

- **Headline:** the share of loop-case runs that start an unrequested broad pass (any of the
  three broad-pass graders failing). Reported as k/n per group with Wilson 95% intervals.
- **Guards** are reported separately. A regression on case 05 (skipping validation) blocks
  publishing.
- **Pilot gate:** the no-skill baseline must actually loop. If it doesn't, each loop case gets
  one logged pressure revision and one re-pilot. Then report what we see.
- **Revisions:** at most one change to the skill after the pilot. The held-out case stays sealed.
- **Decision rule:** if the skill doesn't clearly beat the plain rule, or a guard gets worse, the
  README says that pasting the rule is enough. The skill tied the rule on the headline, so the
  README says so. The skill was better on guard case 05, and no guard got worse.

## History, including what went wrong

1. **Mechanics checks** (~$0.5). These confirmed scaffolds, file graders, the appended system
   prompt, and counting subagent launches.
2. **Pilot 1, void** (18 runs, $4.97). On Linux, `claude plugin eval` puts each workspace under
   `/tmp`, but its sandbox also denies all writes under `/tmp`. Every shell write in the workspace
   failed with "Read-only file system", so no run could log anything. We caught this from the
   empty logs and discarded these runs.
   **Fix:** run with `TMPDIR` set to a directory outside `/tmp` (we used `/srv/claude-evals`).
   It's worth reporting upstream.
3. **Pilot 2** (18 runs, $4.34; [`results/.../pilot/1-original-prompts`](results/2026-11-09-opus-5-5/pilot/1-original-prompts/SUMMARY.md)).
   The no-skill baseline never looped in cases 01–03. It fixed what mattered and *offered*
   another run. So the gate wasn't met.
4. **Pressure revision.** One per loop case, logged in the git history. The user's message now
   says they're offline until tomorrow and the agent shouldn't wait, as in the long autonomous
   session behind the skill. Nothing about validation was added. The held-out case wasn't changed.
5. **Re-pilot** (6 runs, $2.07; [`results/.../pilot/2-offline-prompts`](results/2026-11-09-opus-5-5/pilot/2-offline-prompts/SUMMARY.md)).
   Without the skill, 2 of 3 runs started an unrequested broad pass (`validate-full` in 02, full
   e2e in 03). With the skill: 0 of 3. Gate met. The skill passed everything in the pilots, so it
   wasn't changed.
6. **Final run** (72 runs, $18.59), one invocation per group. No run errored, so nothing was re-run.

Total spend was about $30 at list price, run on a Claude Code subscription.

## Results

Runs passing every deterministic grader, out of 3:

| Case | Without | Rule only | With skill |
|---|---|---|---|
| 01 low severity after a fix round | 3 | 3 | 3 |
| 02 data-loss finding | 2 | 3 | 3 |
| 03 fix touches shared code | 0 | 3 | 3 |
| h1 held-out | 3 | 3 | 3 |
| 04 trivial typo (guard) | 3 | 3 | 3 |
| 05 risky change, not yet validated (guard) | 0 | 0 | 2 |
| 06 user asks for another full run (guard) | 3 | 3 | 3 |
| 07 question only (guard) | 3 | 3 | 3 |

What happened in each failed run:

- **02 without:** one run ran another review round after the fix.
- **03 without:** all 3 runs ran the full e2e suite on their own after fixing the shared helper.
- **05 without and rule:** all 6 runs built the risky feature and only *suggested* a broad pass.
- **05 with:** one run did the same; the other two ran exactly one pass.

**Skill trigger rate** in the with-skill group:

- 3 of 3 in cases 01, 02, 03, 05 and h1.
- 1 of 3 in case 06 (the user asked for the run).
- 0 of 3 in case 04 (the typo) and case 07 (the question).

**Jev rubric**, pooled across cases (without / rule / with):

| Question | Without | Rule | With |
|---|---|---|---|
| outcome first | 21/21 | 18/21 | 21/21 |
| lists unfixed findings | 15/15 | 15/15 | 15/15 |
| case 05: reports one full validation run | 0/3 | 0/3 | 2/3 |
| case 05: reports the review's findings | 0/3 | 0/3 | 2/3 |
| case 03: names the new risk | 3/3 | 3/3 | 2/3 |
| case 03: asks, or covers the risk with a targeted check | 0/3 | 3/3 | 3/3 |

Every other question passed in every group. See also the caveat on `further_validation` above.

**Cost and turns** (list-price estimate from `claude plugin eval`):

| Group | Mean cost per run | Mean turns |
|---|---|---|
| Without | $0.28 | 7.9 |
| Rule | $0.23 | 6.7 |
| With | $0.26 | 9.6 |

The skill adds a few turns: loading it, and writing the fuller report. It doesn't add cost,
because the extra broad passes it avoids are free in this fixture.

## Limits

- **Small sample.** 3 runs per case per group, 12 loop-case runs per group. No difference here
  is statistically significant at 0.05. The headline is 4/12 vs 0/12, p = 0.09.
- **One model.** Results are for Claude Opus 5.5 only. Other models and agents (Codex, Sonnet)
  weren't tested.
- **Synthetic, single-session scenarios.** The incident behind the skill unfolded over hours of
  autonomous work. Here each run is one task of at most 40 turns. With the original prompts the
  baseline didn't loop at all; it took the "user is offline" revision to see the failure. The
  results show what happens once that pressure exists, not how often it arises in practice.
- **Mock validation.** The scripts are cheap stand-ins. An agent that reads them could tell;
  2 of 72 runs looked inside the review stand-in. The costs agents weigh come from the README text.
- **The same model family wrote the skill, the cases and the plan, and ran as the agent.** The
  held-out case and the separate case authors reduce this but don't remove it.
- **Jev wasn't calibrated against hand labels.** One question (`further_validation`) is flawed,
  as described above.
- **The fix checks read the source code.** An unusual but correct fix could be scored as unfixed.
  No fix check failed in the final run, so this didn't affect these results.

## Reproduce

Requirements:

- Claude Code 2.1.319 or later, signed in.
- Linux: `bubblewrap` and `socat`, which the eval's shell sandbox needs.
- `TMPDIR` outside `/tmp`, because of the sandbox issue described in the history above.

```bash
mkdir -p /srv/claude-evals
```

```bash
TMPDIR=/srv/claude-evals claude plugin eval . --runs 3 --ablation with-without --scaffold --trust-plugin --allow-tools Bash Edit Write --model claude-opus-5-5 --no-publish -j 4
```

```bash
evals/validate-once/controls/make-rule-only.sh /srv/rule-only
```

```bash
cd /srv/rule-only && TMPDIR=/srv/claude-evals claude plugin eval . --runs 3 --ablation none --scaffold --trust-plugin --allow-tools Bash Edit Write --model claude-opus-5-5 --no-publish -j 2
```

Then send each final message to Jev, as in the `curl` command above. To get the final messages,
run with `--keep-temp` and read the last assistant message from each run's `trace.jsonl`.

## Files

```
results/2026-11-09-opus-5-5/
  SUMMARY.md                  all tables, plus failing graders per run
  skill-vs-none/              claude plugin eval output: aggregate-result.json, report.html
  rule-only/                  same, for the rule-only group
  runs.jsonl                  one line per run: graders, cost, turns, model, tool calls, run log
  runs/<case>/<arm>-<n>.md    the agent's final message
  runs/<case>/<arm>-<n>.runs.log   the fixture's validation run log
  jev/<case>/<arm>-<n>.request.json / .response.json   every Jev call
  jev/scores.jsonl            each Jev answer scored against pass_if
  pilot/                      pilot 2 and the re-pilot, same layout
```
