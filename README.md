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

In practice the agent:

1. sizes validation to the change: fast checks for trivial changes, exactly one broad pass for
   risky ones;
2. runs cheap checks while building and the broad pass once, at the end (review first, then
   end-to-end on the version that ships);
3. triages findings once: must-fix, text-only nit, known limit, or needs a decision;
4. confirms each fix with a targeted check (the failing test or one scenario), never the whole
   suite;
5. runs another broad pass only after naming the concrete new risk, and asks first when it's
   expensive;
6. stops and reports, outcome first, with a short "Known limits" list.

It does not make agents skip validation: a risky change still gets its one broad pass, and
explicit requests for more validation are honoured.

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

To pin a release, use the tag: `npx skills add https://github.com/chenstanilovsky/skills/tree/v0.1.0 --skill validate-once`, or `claude plugin marketplace add chenstanilovsky/skills#v0.1.0`.

### Does it work?

RESULTS_PLACEHOLDER

## Repository layout

```
skills/<skill>/SKILL.md            the skills (installed by npx skills and by the plugin)
.claude-plugin/plugin.json         Claude Code plugin
.claude-plugin/marketplace.json    marketplace listing this repo's plugin
evals/<skill>/                     evals for each skill, kept out of the installed skill folders
```

## License

[MIT](LICENSE)
