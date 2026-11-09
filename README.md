# skills

Agent skills by Chen. MIT licensed.

| Skill | What it does |
|---|---|
| [`validate-once`](skills/validate-once/SKILL.md) | Stops coding agents from looping through expensive validation. |

## validate-once

Coding agents tend to fall into an expensive loop: make a change, run a broad validation pass
(full end-to-end suite, several reviewer agents, adversarial or skeptic review), fix the small
things it finds, run the broad pass again, find smaller things, and so on. Each round finds
something, because a broad pass over mostly-correct code always does. In the session that led
to this skill, an agent ran six such rounds at about 1.7–2 million subagent tokens and an hour
each; the later rounds chased rare edge cases.

The skill teaches one rule:

> Validate once, in proportion to risk. Run at most one broad validation pass (live end-to-end
> checks, multi-agent or adversarial review) per change. Fix only the findings that break the
> request, an agreed rule, safety or data integrity, and confirm those fixes with targeted
> checks, not another broad pass. Report remaining low-severity, edge-case and polish findings
> as known limits instead of starting another fix-and-validate round; a further broad pass needs
> a concrete new risk and, when expensive, the user's agreement.

The skill tells the agent to:

1. size validation to the change: fast checks for trivial changes, exactly one broad pass for
   risky ones;
2. run cheap checks while building and the broad pass once, at the end (review first, then
   end-to-end on the version that ships);
3. triage findings once: must-fix, text-only nit, known limit, or needs a decision;
4. confirm each fix with a targeted check (the failing test or one scenario), never the whole
   suite;
5. run another broad pass only after naming the concrete new risk, and ask first when it's
   expensive;
6. stop and report, outcome first, with a short "Known limits" list.

It is written so that agents don't skip validation: a risky change gets its one broad pass, and
explicit requests for more validation are honoured. In testing, the agent ran that pass in 2 of 3
runs (see below).

### Install

With the [`skills` CLI](https://github.com/vercel-labs/skills) (Claude Code, Codex and other agents):

```bash
npx skills add chenstanilovsky/skills --skill validate-once
```

As a Claude Code plugin:

```bash
claude plugin marketplace add chenstanilovsky/skills
```

```bash
claude plugin install validate-once@chenstanilovsky-skills
```

Or in one step inside Claude Code: `/plugin install validate-once --marketplace chenstanilovsky/skills`.

To pin a release, use its tag (releases start at `v0.1.0`): `npx skills add https://github.com/chenstanilovsky/skills/tree/v0.1.0 --skill validate-once`, or `claude plugin marketplace add chenstanilovsky/skills#v0.1.0`.

### Does it work?

Partly. Tested on **Claude Opus 5.5** (Claude Code 2.1.319) on **2026-11-09**: 8 synthetic
scenarios, 3 runs each, in three groups. "Rule only" means the rule paragraph above, added as one
system-prompt instruction, with no skill. Cell = runs that passed every check, out of 3.

| Scenario | Without | Rule only | With skill |
|---|---|---|---|
| Only low-severity findings left after a fix round | 3/3 | 3/3 | 3/3 |
| One data-loss finding | 2/3 | 3/3 | 3/3 |
| The fix changes shared code that only the full suite covers | 0/3 | 3/3 | 3/3 |
| Held-out scenario, written without seeing the skill | 3/3 | 3/3 | 3/3 |
| Risky change that hasn't been validated yet | 0/3 | 0/3 | 2/3 |
| Trivial typo on release day | 3/3 | 3/3 | 3/3 |
| User asks for one more full run | 3/3 | 3/3 | 3/3 |
| Plain question, no change | 3/3 | 3/3 | 3/3 |

- **Unrequested broad passes:** in the four scenarios where findings arrive after a broad pass has
  already run, the agent without the skill started another one in 4 of 12 runs (95% interval
  14–61%). With the skill: 0 of 12 (0–24%). That's not a long loop: each of those runs started
  exactly one extra pass, and 3 of the 4 were in one scenario, where the agent ran the full
  end-to-end suite once after naming a shared-code risk. The skill asks first in that situation.
  Only 1 run repeated a review round.
- **On that measure, the rule alone did as well as the skill** (0 of 12). If you only want this
  part, putting the paragraph above in your `CLAUDE.md` or `AGENTS.md` is the closest equivalent.
  That wasn't tested: the test added it as a system-prompt instruction. One difference the checks
  don't count: in the shared-code scenario, the rule-only agent ran 5–6 single end-to-end
  scenarios one after another, and the skill ran 1–3.
- **What the skill adds:** on a risky change nobody had validated, it ran one review round in
  2 of 3 runs. Without the skill, and with the rule alone, every run (0 of 3 each) finished after
  fast checks and recommended the review instead of running it. The rule says "at most one"; the
  skill also says a risky change *gets* one. This rests on 3 runs per group (p = 0.4), and one of
  the two passing runs had read the review stand-in's source first.
- **Report wording:** Jev, a typed-decision judge, checked each final report. Every skill report
  led with the outcome and listed what wasn't fixed. So did every no-skill report; rule-only
  reports led with the outcome in 18 of 21. On whether
  a report offered another full run without naming a risk, the skill passed 6 of 12 and the rule
  10 of 12. Some of that is real wording ("if you still want it…"), and some is the judge
  misreading a report that did name the risk.
- **Limits:**
  - The sample is small: p = 0.09 for 4/12 vs 0/12, and runs cluster by scenario.
  - One model only.
  - The scenarios are synthetic single sessions with cheap stand-ins for the expensive scripts.
  - The baseline only started extra passes once the scenario said the user was offline and not to wait.
  - Jev wasn't checked against hand labels.
  - The skill costs about the same as no skill, and about 10% more than the rule alone (a few
    more turns).

How it was tested, every run, and every judge call:
[`evals/validate-once/EVALUATION.md`](evals/validate-once/EVALUATION.md).

## Repository layout

```
skills/<skill>/SKILL.md            the skills (installed by npx skills and by the plugin)
.claude-plugin/plugin.json         Claude Code plugin
.claude-plugin/marketplace.json    marketplace listing this repo's plugin
evals/<skill>/                     evals for each skill, kept out of the installed skill folders
```

## License

[MIT](LICENSE)
