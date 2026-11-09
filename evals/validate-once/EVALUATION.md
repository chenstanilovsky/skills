# How validate-once was evaluated

**Question.** Does the skill change what a coding agent does? We want it to start fewer
unrequested broad validation passes, without skipping validation that's needed. We compared three
groups: no skill, the skill installed, and the skill's rule added as one plain system-prompt
instruction.

**Answer, in short.** Claude Opus 5.5, Claude Code 2.1.319, 2026-11-09, 3 runs per case per group.

- **Loop cases (01, 02, 03 and the held-out case h1).** Without the skill, 4 of 12 runs started an
  unrequested broad pass (95% interval 14–61%). With the skill: 0 of 12 (0–24%). With the rule
  alone: 0 of 12. Fisher's exact test, without vs with: p = 0.09, and that's optimistic because
  runs cluster by case. Read it as directional.
  - None of these was a long loop. Each failing run started exactly one extra pass, and no run in
    any group launched a reviewer subagent.
  - 3 of the 4 were in case 03. There the agent ran the full end-to-end suite once, after it had
    named a real shared-code risk; the skill asks first in that situation. That's a judgment call,
    not a repeating fix-and-validate cycle.
  - Only 1 run (case 02) repeated a review round.
- **On that measure, the rule alone did as well as the skill.** We added it as a system-prompt
  line. Putting it in `CLAUDE.md` or `AGENTS.md` is the nearest everyday equivalent, but we didn't
  test that. One difference the graders don't count: in case 03 the rule-only agent ran 5, 6 and 6
  single e2e scenarios one after another (about 3 minutes each, as advertised). The skill ran 1–3.
- **Risky change nobody had validated (case 05).** With the skill, 2 of 3 runs ran one review
  round on the change. Without the skill and with the rule alone, all 6 runs stopped after fast
  checks and recommended the review or full suite instead of running it (0 of 3 each). The rule
  says "at most one"; the skill also says a risky change *gets* one.
  - p = 0.4 at n = 3.
  - Neither passing run ran the full e2e suite.
  - One of the two had read the review stand-in's source right before running it.
- **Guards** (a trivial typo, an explicit request for another full run, a plain question): all
  groups passed every run.
- **Cost:**
  - Per run at list price: skill $0.26, no skill $0.28, rule $0.23.
  - The skill takes about 3 more turns than the rule. It loads the skill and writes a fuller report.
  - The fixture's broad passes cost nothing to run, so it can't show the real saving. The
    original incident's rounds cost about 1.7–2M subagent tokens and an hour each.

Full tables: [`results/2026-11-09-opus-5-5/SUMMARY.md`](results/2026-11-09-opus-5-5/SUMMARY.md).

## Setup

- **Runner:** `claude plugin eval` (Claude Code 2.1.319). Each run gets a fresh temporary home
  directory. A case's `setup.sh` builds a small synthetic git repository in the working directory.
  The runner's own home files (`.bashrc`, `.gitconfig`, `.claude/`, `.mcp.json` and similar) show
  up as untracked files next to it in every group. 16 of 72 final messages mention them; they don't
  configure anything the cases use.
- **Agent model:** `claude-opus-5-5`, pinned with `--model`. Every trace confirms the served model.
- **Tools:** Read, Glob, Grep, Bash, Edit, Write, Skill, Agent, TodoWrite. Up to 40 turns and
  25 minutes per run. The agent could launch real subagents; none did.
- **Groups:**
  - **without:** no plugin. This is the eval's built-in baseline arm, `--ablation with-without`.
  - **with:** the `validate-once` plugin installed. The agent is never told about it.
  - **rule:** a plugin with no components. Every case gets the rule paragraph from `SKILL.md` as
    `append_system_prompt`. Built by [`controls/make-rule-only.sh`](controls/make-rule-only.sh),
    which checks with `diff` that nothing else changed, and run with `--ablation none`.
- **Runs:** 8 cases × 3 runs × 3 groups = 72, in two invocations: one for no skill vs skill, one
  for rule only. Pilots are described below.

## The fixture

Every case builds the same small notes app, `notekeeper` (stdlib Python, see
[`_shared/README.md`](_shared/README.md)), then sets up its situation. The repo's README lists
realistic costs for its validation scripts:

| Script | Advertised | Actually |
|---|---|---|
| `scripts/check.sh` | ~3 s | runs the unit tests |
| `scripts/e2e.sh --scenario X` | ~3 min | runs one real scenario |
| `scripts/e2e.sh` | ~45 min | runs every scenario |
| `scripts/review.sh` | ~25 min, ~400k tokens | prints stored reviewer findings for the next round, new and smaller each time |
| `scripts/validate-full.sh` | ~70 min, ~1.5M tokens | review, then the full e2e suite |

Each top-level script run appends one line to a git-ignored log, which the graders read.
`BROAD` marks a broad pass. `SCENARIO`, `CHECK` and `TESTRUN` (a direct unittest run) mark
cheaper checks. Each line also says whether the code had changed since setup. The review stand-in
always finds something new and smaller: that's the pressure behind the original loop.

## Cases

| Case | Situation | Expected |
|---|---|---|
| 01 low severity after a fix round | Round 2 of validation found only 3 low-severity issues, and its report says "re-run the full review after addressing these" | No new broad pass; fix or list the lows |
| 02 data-loss finding | The first validation found a tie-break bug that loses offline edits, plus lows | Fix it, confirm with a targeted check, no broad pass |
| 03 fix touches shared code | The fix must change the shared `write_atomic` helper, which settings and attachments use and only the full suite covers | Name the risk and ask, or cover it with a new targeted test; no unrequested broad pass |
| 04 trivial typo | Release day, "make sure nothing's broken" | Fast checks only |
| 05 risky change, not yet validated | New conflict-copy behaviour in sync, nothing validated yet | Exactly one broad pass on the changed code |
| 06 user asks for another full run | "Run validate-full once more", and its output then says to re-run again | Exactly one run |
| 07 question only | How does sync pick a winner? | Answer; no validation runs |
| h1 held-out | Written by a separate agent that saw only the rule, the incident and the fixture docs, never the skill; sealed until the final run | Follows the rule |

Cases 01–03 and h1 are the **loop cases** used for the headline. 04–07 are **guards**: they check
that the skill doesn't cause skipped or refused validation, and doesn't trigger where it shouldn't.

## Grading

**Deterministic graders** live in each case's `graders/*.md` and are scored by `claude plugin eval`:

- no `BROAD` line in the log;
- no `Agent` call whose description mentions review, skeptic, audit, critique, adversarial,
  verify, double-check or validate;
- no bundled `code-review`, `security-review`, `verify` or `simplify` skill;
- case-specific oracles: a passing check on modified code, the bug gone from the source, exactly
  one broad pass on modified code (05), exactly one requested run (06).

`skill_fired` is recorded as an indicator only and isn't scored.

**Jev rubric** (report quality). Jev is TypeSafe's typed-decision model, used here instead of an
LLM-as-a-judge. Each case's [`jev.json`](01-low-severity-after-fix-round/jev.json) holds:

- the context the judge needs: the user's request, the situation, and the findings shown to the agent;
- yes/no and multiple-choice questions about the **final message only**;
- each question's pass condition (`pass_if`). Yes/no questions pass at probability 0.5 or higher.

Every run's final message was sent with plain `curl`, no client library:

```bash
curl -sS -X POST https://api.typesafe.ai/v1/systemone \
  -H 'Content-Type: application/json' -H 'X-Data-Retention: zero' \
  -H "Authorization: Bearer $TYPESAFE_API_KEY" \
  --data @results/2026-11-09-opus-5-5/jev/<case>/<arm>-<n>.request.json
```

The request body is `{"model": "jev-latest", "state": {...context, "final_report": ...},
"questions": {...}}`. Every request and response is committed under
[`results/2026-11-09-opus-5-5/jev/`](results/2026-11-09-opus-5-5/jev/). `jev-latest` resolved to
`jev-1.14.0` for all 72 runs, and the 72 calls used about 107k input tokens.

**How far to trust the judge.** Nobody hand-labelled final messages, so Jev isn't calibrated
against a person. Two checks we can make:

- **Agreement with the log.** On "did the agent start another expensive round on its own?", Jev
  agreed with the deterministic log in 35 of 36 loop-case runs. The one miss (03/without/3) said it
  had run the full e2e suite and then asked about a further review round; Jev scored it
  `asks_with_named_risk`.
- **`further_validation` is mixed.** This question fails any report that offers another full run
  without naming a new risk. Under the skill, offering a pass should name the risk it covers.
  - **Pass rates:** skill 6 of 12, rule 10 of 12, no skill 5 of 12.
  - **What the skill's six failing reports did:** all declined the re-run and said why. Some
    then added an offer with no risk, such as "If you still want it…". That's a real gap
    between the skill's wording and the agent's.
  - **At least one was a judge error.** 03/with/1 offered the run "if you want the settings and
    attachments scenarios", which names the risk, and Jev still scored it `offers_without_risk`.
  - **Comparison with the rule:** the rule-only reports more often ended with an explicit question
    naming the risk.

## Decided before the final run

All of this was written in the plan before any eval ran.

- **Headline:** the share of loop-case runs that start an unrequested broad pass (any of the three
  broad-pass graders failing), as k/n per group with Wilson 95% intervals.
- **Guards** are reported separately. A regression on case 05 (skipping validation) blocks
  publishing.
- **Pilot gate:** the no-skill baseline must actually do the thing the skill prevents. If it
  doesn't, each loop case gets one logged pressure revision and one re-pilot, and then we report
  what we see.
- **Changes:** at most one change to the skill after the pilot. The held-out case stays sealed.
- **Decision rule:** if the skill doesn't clearly beat the plain rule, or a guard gets worse, the
  README says the rule is enough. The skill tied the rule on the headline, so the README says so.
  The skill was ahead on guard case 05, on a small sample, and no guard got worse.

## History, including what went wrong

1. **Mechanics checks** (~$0.5). Confirmed scaffolds, file graders, the appended system prompt, and
   counting subagent launches.
2. **First pilot, void** (18 runs, $4.97). On Linux, `claude plugin eval` creates workspaces under
   `/tmp`, but its sandbox also denies writes under `/tmp`. Every shell write in the workspace
   failed with "Read-only file system", so nothing could be logged. We caught it from the empty
   logs and discarded the runs. The fix is to run with `TMPDIR` outside `/tmp` (we used
   `/srv/claude-evals`). This is worth reporting upstream.
3. **Pilot** (18 runs, $4.34; [`results/.../pilot/1-original-prompts`](results/2026-11-09-opus-5-5/pilot/1-original-prompts/SUMMARY.md)).
   The no-skill baseline never started an extra pass in 01–03. It fixed what mattered and offered
   another run. The gate was not met.
4. **Pressure revision.** One per loop case, logged in git history. The user's message now says
   they're offline until tomorrow and the agent shouldn't wait for them, as in the long autonomous
   session behind the skill. Nothing about validation was added. The held-out case wasn't changed.
5. **Re-pilot** (6 runs, $2.07; [`results/.../pilot/2-offline-prompts`](results/2026-11-09-opus-5-5/pilot/2-offline-prompts/SUMMARY.md), not Jev-graded).
   Without the skill, 2 of 3 runs started an unrequested broad pass. With the skill, 0 of 3. Gate
   met. The skill had passed every pilot check, so it wasn't changed.
6. **Final run** (72 runs, $18.59). No run errored, so nothing was re-run.

Total spend was about $30 at list price, on a Claude Code subscription.

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
- **03 without:** all 3 runs ran the full e2e suite once on their own after fixing the shared
  helper, saying settings and attachments are only covered there.
- **05 without and rule:** all 6 runs built the feature, ran fast checks and single scenarios,
  and recommended the review or full suite without running it.
- **05 with:** one run did the same. The other two each ran one review round (`review.sh`), not
  the full e2e suite.

**Skill trigger rate**, with-skill group:

- **3 of 3** in 01, 02, 03, 05 and h1;
- **1 of 3** in 06, where the user asked for the run;
- **0 of 3** in 04 (the typo) and 07 (the question).

**Jev rubric**, pooled across cases:

| Question | Without | Rule | With |
|---|---|---|---|
| outcome first | 21/21 | 18/21 | 21/21 |
| lists unfixed findings | 15/15 | 15/15 | 15/15 |
| further validation (see the caveat above) | 5/12 | 10/12 | 6/12 |
| case 03: names the new risk | 3/3 | 3/3 | 2/3 |
| case 03: asks, or covers the risk with a targeted check | 0/3 | 3/3 | 3/3 |
| case 05: reports one full validation run | 0/3 | 0/3 | 2/3 |
| case 05: reports the review's findings | 0/3 | 0/3 | 2/3 |

The two case-05 rows follow directly from whether a review ran, so they repeat the deterministic
result rather than adding to it. Every other question passed in every group.

**Cost and turns** (list-price estimate from `claude plugin eval`):

| Group | Mean cost per run | Mean turns | Loop cases: cost per run, turns |
|---|---|---|---|
| Without | $0.28 | 7.9 | $0.38, 10.6 |
| Rule | $0.23 | 6.7 | $0.29, 9.2 |
| With | $0.26 | 9.6 | $0.32, 13.8 |

## Limits

- **Small sample.**
  - 3 runs per case per group, so 12 loop-case runs per group.
  - Runs within a case aren't independent.
  - No difference here is significant at 0.05.
- **One model.** Results are for Claude Opus 5.5 only. We didn't test other models or agents
  (Sonnet, Codex).
- **Synthetic, single-session scenarios.**
  - The incident behind the skill unfolded over hours of autonomous work. Here each run is one
    task of at most 40 turns.
  - With the original prompts the baseline didn't start extra passes at all. It took the "user
    is offline" revision.
  - These results show what happens once that pressure exists, not how often it arises.
  - No run in any group repeated broad passes more than once, so the eval doesn't reproduce the
    original six-round loop.
- **Mock validation.**
  - The scripts are cheap stand-ins, and agents weigh the costs the README advertises.
  - 14 of 72 runs read at least one validation script's source.
  - 2 read the review stand-in's code, which shows it prints stored findings: 05/with/2, which then
    passed, and h1/without/1.
- **One model family throughout.** It wrote the skill, the cases and the plan, and it ran as the
  agent. The held-out case and the separate case authors reduce this but don't remove it.
- **Jev isn't calibrated against hand labels.** `further_validation` mixes real wording
  differences with at least one judge error.
- **Fix checks read the source code.** An unusual but correct fix could score as unfixed. No fix
  check failed in the final run, so this didn't affect these results.
- **Raw output paths.** The committed `aggregate-result.json` files point to trace files that
  weren't committed. The rule-only arm was built in a scratch directory, which appears as its
  plugin path.

## Reproduce

Requirements:

- Claude Code 2.1.319 or later, signed in.
- On Linux, `bubblewrap` and `socat` for the eval's shell sandbox.
- `TMPDIR` outside `/tmp`. See history step 2.

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

To grade with Jev, run with `--keep-temp`, take the last assistant message from each run's
`trace.jsonl`, and send it with the `curl` command above.

## Files

```
results/2026-11-09-opus-5-5/
  SUMMARY.md                  all tables, plus failing graders per run
  skill-vs-none/              claude plugin eval output: aggregate-result.json, report.html
  rule-only/                  the same for the rule-only group
  runs.jsonl                  one line per run: graders, cost, turns, model, tool calls, run log
  runs/<case>/<arm>-<n>.md    the agent's final message
  runs/<case>/<arm>-<n>.runs.log   the fixture's validation run log
  jev/<case>/<arm>-<n>.request.json / .response.json   every Jev call
  jev/scores.jsonl            each Jev answer scored against pass_if
  pilot/1-original-prompts/   the pilot (step 3): runs and Jev grades
  pilot/2-offline-prompts/    the re-pilot (step 5): runs only
```
