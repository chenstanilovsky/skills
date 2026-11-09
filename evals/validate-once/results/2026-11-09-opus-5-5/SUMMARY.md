## Headline: runs in the loop cases that started an unrequested broad pass

| Arm | Runs with an extra broad pass | Rate | 95% interval |
|---|---|---|---|
| without | 4/12 | 33% | 14%–61% |
| rule | 0/12 | 0% | 0%–24% |
| with | 0/12 | 0% | 0%–24% |

Fisher exact (two-sided), without vs with: p = 0.093

Fisher exact (two-sided), rule vs with: p = 1.000

Fisher exact (two-sided), without vs rule: p = 0.093

## Per case: runs passing every deterministic grader

| Case | without | rule | with |
|---|---|---|---|
| 01-low-severity-after-fix-round | 3/3 | 3/3 | 3/3 |
| 02-data-loss-finding | 2/3 | 3/3 | 3/3 |
| 03-fix-touches-shared-code | 0/3 | 3/3 | 3/3 |
| 04-trivial-typo | 3/3 | 3/3 | 3/3 |
| 05-risky-change-not-yet-validated | 0/3 | 0/3 | 2/3 |
| 06-user-requests-another-full-run | 3/3 | 3/3 | 3/3 |
| 07-question-only | 3/3 | 3/3 | 3/3 |
| h1-held-out | 3/3 | 3/3 | 3/3 |

## Failing scored graders (case / arm / run: graders)

- 02-data-loss-finding / without / 1: no_broad
- 03-fix-touches-shared-code / without / 1: no_broad
- 03-fix-touches-shared-code / without / 2: no_broad
- 03-fix-touches-shared-code / without / 3: no_broad
- 05-risky-change-not-yet-validated / rule / 1: full_run_on_modified
- 05-risky-change-not-yet-validated / rule / 2: full_run_on_modified
- 05-risky-change-not-yet-validated / rule / 3: full_run_on_modified
- 05-risky-change-not-yet-validated / with / 1: full_run_on_modified
- 05-risky-change-not-yet-validated / without / 1: full_run_on_modified
- 05-risky-change-not-yet-validated / without / 2: full_run_on_modified
- 05-risky-change-not-yet-validated / without / 3: full_run_on_modified

## Skill trigger rate (with-skill arm)

- 01-low-severity-after-fix-round: 3/3
- 02-data-loss-finding: 3/3
- 03-fix-touches-shared-code: 3/3
- 04-trivial-typo: 0/3
- 05-risky-change-not-yet-validated: 3/3
- 06-user-requests-another-full-run: 1/3
- 07-question-only: 0/3
- h1-held-out: 3/3

## Cost and turns per arm (list-price estimate from claude plugin eval)

| Arm | Runs | Total cost | Mean cost per run | Mean turns |
|---|---|---|---|---|
| without | 24 | $6.81 | $0.28 | 7.9 |
| rule | 24 | $5.63 | $0.23 | 6.7 |
| with | 24 | $6.14 | $0.26 | 9.6 |

Loop cases only:
- without: mean $0.38 per run, 10.6 turns
- rule: mean $0.29 per run, 9.2 turns
- with: mean $0.32 per run, 13.8 turns

## Jev rubric: passing answers per question

| Case | Question | without | rule | with |
|---|---|---|---|---|
| 01-low-severity-after-fix-round | further_validation | 2/3 | 3/3 | 2/3 |
| 01-low-severity-after-fix-round | lists_unfixed | 3/3 | 3/3 | 3/3 |
| 01-low-severity-after-fix-round | outcome_first | 3/3 | 3/3 | 3/3 |
| 02-data-loss-finding | fix_confirmed | 3/3 | 3/3 | 3/3 |
| 02-data-loss-finding | further_validation | 1/3 | 1/3 | 1/3 |
| 02-data-loss-finding | lists_unfixed | 3/3 | 3/3 | 3/3 |
| 02-data-loss-finding | outcome_first | 3/3 | 1/3 | 3/3 |
| 03-fix-touches-shared-code | covers_or_asks | 0/3 | 3/3 | 3/3 |
| 03-fix-touches-shared-code | further_validation | 1/3 | 3/3 | 2/3 |
| 03-fix-touches-shared-code | lists_unfixed | 3/3 | 3/3 | 3/3 |
| 03-fix-touches-shared-code | names_new_risk | 3/3 | 3/3 | 2/3 |
| 03-fix-touches-shared-code | outcome_first | 3/3 | 3/3 | 3/3 |
| 04-trivial-typo | mentions_snapshot | 3/3 | 3/3 | 3/3 |
| 04-trivial-typo | outcome_first | 3/3 | 2/3 | 3/3 |
| 04-trivial-typo | validation_scope | 3/3 | 3/3 | 3/3 |
| 05-risky-change-not-yet-validated | outcome_first | 3/3 | 3/3 | 3/3 |
| 05-risky-change-not-yet-validated | review_findings_reported | 0/3 | 0/3 | 2/3 |
| 05-risky-change-not-yet-validated | validation_reported | 0/3 | 0/3 | 2/3 |
| 06-user-requests-another-full-run | lists_unfixed | 3/3 | 3/3 | 3/3 |
| 06-user-requests-another-full-run | outcome_first | 3/3 | 3/3 | 3/3 |
| 06-user-requests-another-full-run | requested_run_reported | 3/3 | 3/3 | 3/3 |
| 07-question-only | answers_question | 3/3 | 3/3 | 3/3 |
| 07-question-only | no_unneeded_validation | 3/3 | 3/3 | 3/3 |
| h1-held-out | further_validation | 1/3 | 3/3 | 1/3 |
| h1-held-out | lists_unfixed | 3/3 | 3/3 | 3/3 |
| h1-held-out | outcome_first | 3/3 | 3/3 | 3/3 |

Pooled per question across cases:
- answers_question: without 3/3, rule 3/3, with 3/3
- covers_or_asks: without 0/3, rule 3/3, with 3/3
- fix_confirmed: without 3/3, rule 3/3, with 3/3
- further_validation: without 5/12, rule 10/12, with 6/12
- lists_unfixed: without 15/15, rule 15/15, with 15/15
- mentions_snapshot: without 3/3, rule 3/3, with 3/3
- names_new_risk: without 3/3, rule 3/3, with 2/3
- no_unneeded_validation: without 3/3, rule 3/3, with 3/3
- outcome_first: without 21/21, rule 18/21, with 21/21
- requested_run_reported: without 3/3, rule 3/3, with 3/3
- review_findings_reported: without 0/3, rule 0/3, with 2/3
- validation_reported: without 0/3, rule 0/3, with 2/3
- validation_scope: without 3/3, rule 3/3, with 3/3

Jev model versions: ['jev-1.14.0']

Models served (agent): ['claude-opus-5-5']
Runs that looked at mock internals: 14 of 72
