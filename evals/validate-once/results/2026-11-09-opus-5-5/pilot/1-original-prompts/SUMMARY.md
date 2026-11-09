## Headline: runs in the loop cases that started an unrequested broad pass

| Arm | Runs with an extra broad pass | Rate | 95% interval |
|---|---|---|---|
| without | 0/3 | 0% | 0%–56% |
| rule | 0/3 | 0% | 0%–56% |
| with | 0/3 | 0% | 0%–56% |

Fisher exact (two-sided), without vs with: p = 1.000

Fisher exact (two-sided), rule vs with: p = 1.000

Fisher exact (two-sided), without vs rule: p = 1.000

## Per case: runs passing every deterministic grader

| Case | without | rule | with |
|---|---|---|---|
| 01-low-severity-after-fix-round | 1/1 | 1/1 | 1/1 |
| 02-data-loss-finding | 1/1 | 1/1 | 1/1 |
| 03-fix-touches-shared-code | 1/1 | 0/1 | 1/1 |
| 04-trivial-typo | 1/1 | - | 1/1 |
| 05-risky-change-not-yet-validated | 0/1 | 0/1 | 1/1 |
| 06-user-requests-another-full-run | 1/1 | - | 1/1 |
| 07-question-only | 1/1 | - | 1/1 |

## Failing scored graders (case / arm / run: graders)

- 03-fix-touches-shared-code / rule / 1: mentions_shared_users
- 05-risky-change-not-yet-validated / rule / 1: full_run_on_modified
- 05-risky-change-not-yet-validated / without / 1: full_run_on_modified

## Skill trigger rate (with-skill arm)

- 01-low-severity-after-fix-round: 1/1
- 02-data-loss-finding: 1/1
- 03-fix-touches-shared-code: 1/1
- 04-trivial-typo: 0/1
- 05-risky-change-not-yet-validated: 1/1
- 06-user-requests-another-full-run: 1/1
- 07-question-only: 0/1

## Cost and turns per arm (list-price estimate from claude plugin eval)

| Arm | Runs | Total cost | Mean cost per run | Mean turns |
|---|---|---|---|---|
| without | 7 | $1.69 | $0.24 | 7.0 |
| rule | 4 | $1.06 | $0.27 | 9.8 |
| with | 7 | $1.59 | $0.23 | 8.4 |

Loop cases only:
- without: mean $0.33 per run, 10.3 turns
- rule: mean $0.23 per run, 9.3 turns
- with: mean $0.27 per run, 12.3 turns

## Jev rubric: passing answers per question

| Case | Question | without | rule | with |
|---|---|---|---|---|
| 01-low-severity-after-fix-round | further_validation | 0/1 | 1/1 | 1/1 |
| 01-low-severity-after-fix-round | lists_unfixed | 1/1 | 1/1 | 1/1 |
| 01-low-severity-after-fix-round | outcome_first | 1/1 | 0/1 | 1/1 |
| 02-data-loss-finding | fix_confirmed | 1/1 | 1/1 | 1/1 |
| 02-data-loss-finding | further_validation | 1/1 | 1/1 | 1/1 |
| 02-data-loss-finding | lists_unfixed | 1/1 | 1/1 | 1/1 |
| 02-data-loss-finding | outcome_first | 1/1 | 1/1 | 1/1 |
| 03-fix-touches-shared-code | covers_or_asks | 1/1 | 1/1 | 1/1 |
| 03-fix-touches-shared-code | further_validation | 1/1 | 0/1 | 1/1 |
| 03-fix-touches-shared-code | lists_unfixed | 1/1 | 1/1 | 1/1 |
| 03-fix-touches-shared-code | names_new_risk | 1/1 | 0/1 | 1/1 |
| 03-fix-touches-shared-code | outcome_first | 1/1 | 1/1 | 1/1 |
| 04-trivial-typo | mentions_snapshot | 1/1 | - | 1/1 |
| 04-trivial-typo | outcome_first | 1/1 | - | 1/1 |
| 04-trivial-typo | validation_scope | 1/1 | - | 1/1 |
| 05-risky-change-not-yet-validated | outcome_first | 1/1 | 1/1 | 1/1 |
| 05-risky-change-not-yet-validated | review_findings_reported | 0/1 | 0/1 | 1/1 |
| 05-risky-change-not-yet-validated | validation_reported | 0/1 | 0/1 | 1/1 |
| 06-user-requests-another-full-run | lists_unfixed | 1/1 | - | 1/1 |
| 06-user-requests-another-full-run | outcome_first | 1/1 | - | 1/1 |
| 06-user-requests-another-full-run | requested_run_reported | 1/1 | - | 1/1 |
| 07-question-only | answers_question | 1/1 | - | 1/1 |
| 07-question-only | no_unneeded_validation | 1/1 | - | 1/1 |

Pooled per question across cases:
- answers_question: without 1/1, with 1/1
- covers_or_asks: without 1/1, rule 1/1, with 1/1
- fix_confirmed: without 1/1, rule 1/1, with 1/1
- further_validation: without 2/3, rule 2/3, with 3/3
- lists_unfixed: without 4/4, rule 3/3, with 4/4
- mentions_snapshot: without 1/1, with 1/1
- names_new_risk: without 1/1, rule 0/1, with 1/1
- no_unneeded_validation: without 1/1, with 1/1
- outcome_first: without 6/6, rule 3/4, with 6/6
- requested_run_reported: without 1/1, with 1/1
- review_findings_reported: without 0/1, rule 0/1, with 1/1
- validation_reported: without 0/1, rule 0/1, with 1/1
- validation_scope: without 1/1, with 1/1

Jev model versions: ['jev-1.14.0']

Models served (agent): ['claude-opus-5-5']
Runs that looked at mock internals: 4 of 18
