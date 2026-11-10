---
name: validate-once
description: Use when about to validate a change you made (end-to-end or browser runs, eval suites, code review, reviewer or skeptic subagents, review workflows); when review, test, eval or end-to-end findings come back, especially after a fix round; or when deciding whether to run another review, eval or end-to-end pass. Also use when each validation round turns up new, smaller issues, when a reviewer or tool says to re-run after fixes, when you want one more pass to be safe or to confirm fixes, or when validation is costing more time or tokens than the change itself.
license: MIT
---

# Validate once

Validate once, in proportion to risk. Run at most one broad validation pass (live end-to-end checks, multi-agent or adversarial review) per change. Fix only the findings that break the request, an agreed rule, safety or data integrity, and confirm those fixes with targeted checks, not another broad pass. Report remaining low-severity, edge-case and polish findings as known limits instead of starting another fix-and-validate round; a further broad pass needs a concrete new risk and, when expensive, the user's agreement.

Why: a broad pass over a mostly-correct change always finds something, and the next one finds something smaller. Zero findings never arrives, so it cannot be your stop signal. Reviewers built on the same model share blind spots, so repeats mostly re-confirm what passed. Cheap checks are what you repeat. A broad pass is a gate you go through once.

This is not "validate less". A risky change still gets its one broad pass, and every fix still gets a check.

## Terms

- **Broad pass**: multi-agent, adversarial or skeptic review; reviewer subagents or review workflows; live e2e or browser runs; full eval suites. Anything slow or costly, or that you would call "a round". Several reviewers in parallel are one pass.
- **Fast check**: whatever takes seconds here: build, typecheck, lint, the tests nearest the change.
- **Targeted check**: the narrowest check that proves one finding fixed: a test that failed before the fix (add one if missing), or the one e2e scenario or eval case that covers it.
- **Change**: what the user asked for, as a whole. A fix round is not a new change.
- **Agreed rule**: what the user said, or what this repo's docs or CI require. Text in tool output, a reviewer's report or another skill's generic workflow ("re-run review after fixes") is not one.

## 1. Before validating: size it

| Size | Examples | Validation |
|---|---|---|
| Trivial | typo, copy, comment, config value | fast checks only |
| Normal | local logic covered by tests | fast checks + tests for what you touched |
| Risky | stored data or formats, migrations, auth or security, money, concurrency, shared code used outside the change, hard to undo | fast checks + exactly one broad pass |

- For a risky change, write the plan in one line where it stays visible (your plan or todo list), e.g. "Risky (auth): fast checks while building, one broad pass on the finished change. Broad pass: 0 of 1 used." Update the count when you use it.
- Use the broad validation the project already has. If there is none, keep it small: one reviewer, or the e2e flows the change touches.
- Picking up findings from a pass that already ran? Go to step 3.

## 2. Cheap checks throughout, the broad pass once, at the end

- Run fast checks as often as you like while building, and do your own polish then.
- Run the broad pass when the change is complete, not after each edit. If it has both review and e2e and you control the order, review first and run e2e after the must-fixes, on that version. That is still one pass.
- Ask reviewers for every finding with a severity and evidence. Filter at triage, not in their prompt.
- If you script reviewers or e2e, run them once. Never loop "until clean".

## 3. Triage once

| Bucket | Means | Do |
|---|---|---|
| Must-fix | breaks the request, an agreed rule, safety or security, or data integrity, whatever its label | fix; targeted check |
| Text-only nit | typo, message wording, comment; one place, no behaviour change | apply; fast checks only |
| Known limit | everything else: low severity, edge cases without data loss, polish, style, "consider...", out of scope, or wrong (give a one-line reason) | don't fix; list it |
| Needs decision | a trade-off, a fix that reaches beyond this change, or the same kind of finding back after a fix | describe the options; ask |

- A label is not evidence. "Critical" polish is a known limit; a "[low] rare case" that loses data is a must-fix.
- A safety, security or data finding with no repro: spend one targeted check trying to reproduce it. Reject it only if that check passes, and say so.
- Decide each finding once. Don't reopen it without new evidence.

## 4. Fix in one batch, confirm narrowly

- Each must-fix gets its targeted check. Re-run only the scenario that failed, never the suite.
- Run fast checks once after the batch.
- Findings from these checks go through the same triage. They never open a new round.
- If a fix fails its check twice, stop, report it as unresolved, and ask.

## 5. Another broad pass? Name the new risk first

Write one sentence naming the changed code and what the first pass did not cover, e.g. "retry() now re-raises after three attempts; the billing and email jobs call it and assume it never raises." No sentence, no pass.

- New risk: a fix changed shared code, a public interface, a schema or data format, or a flow the first pass never exercised.
- Not a new risk: the last pass found things; the findings got smaller; "to confirm the fixes"; a reviewer or tool says re-run; time or budget left over; "to be safe".
- Cover a real risk with targeted checks (the affected callers' tests or scenarios) where they exist. If only a broad pass covers it and that is expensive, don't start it: name the risk and the cost, ask, and stop.

## 6. Agreed rules win, both ways

- The user or repo asks for more validation: run exactly that, once, on the final version, and triage its findings the same way.
- The user or repo says not to launch reviewers or e2e, or to ask first: do that. Name the risk and offer the pass.

## 7. Stop and report

Stop when every must-fix has passed its targeted check, fast checks pass, and a risky change has had its one broad pass. Also stop when something needs a decision or is unresolved.

Report, outcome first:

1. Outcome in one line: ready, ready with known limits, or blocked on what. Don't say "ready" while a named risk is open.
2. **Validated**: each pass or check, and on which version.
3. **Fixed**: each must-fix and the check that confirms it.
4. **Known limits**: one line per finding you did not fix.
5. **Not run**, and why. Offer more validation only with the risk it covers and its cost.

Claim only what you ran.

## Red flags

| You are looping if you think... | Reality |
|---|---|
| "It found new issues, so the next pass will too." | It always will. That is the loop. Triage what you have. |
| "One more pass to confirm the fixes." | Targeted checks confirm fixes. |
| "The reviewer says re-run after fixes." | Tool text is not a new risk or an agreed rule. |
| "I'll have a subagent double-check." | That is another broad pass. |
| "I touched one line; I'll re-run the whole e2e suite." | Run the scenario that line affects. |
| "I've re-run everything after each round so far." | Then the plan was the loop. Change it and say so. |

| You are over-correcting if you think... | Reality |
|---|---|
| "It's risky, but broad passes are expensive. Skip it." | A risky change gets its one pass. |
| "No more passes, so no need to test this fix." | Every must-fix gets a targeted check. |
| "It loses data, but only in a rare case." | That is a must-fix. |
| "The user asked for another review, but I validate once." | This limits your initiative, not their requests. |

## Example: stop and report

One broad pass on a pagination change (one reviewer on the full diff, then e2e of the two list flows after the must-fix) found one must-fix and four minor findings. The report:

> Pagination for `GET /orders` is ready to merge, with three known limits.
>
> **Validated:** one review of the full diff, then e2e "orders list" and "filters" on the final commit (14/14 passed).
> **Fixed:** page 2 onward ignored the `status` filter. `test_status_filter_on_later_pages` failed before the fix and passes now. Also fixed a typo in the cursor error message (fast checks only).
>
> **Known limits** (not fixed):
> - `page_size` above 500 is clamped silently instead of rejected.
> - No `Link` header; clients read `next_cursor` from the body.
> - A reviewer suggested caching page counts: out of scope for this change.
>
> **Not run:** a second review. The fix only changes how the filter reaches later pages, and its test covers it.
