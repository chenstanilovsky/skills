## Headline: runs in the loop cases that started an unrequested broad pass

| Arm | Runs with an extra broad pass | Rate | 95% interval |
|---|---|---|---|
| without | 2/3 | 67% | 21%–94% |
| rule | - | - | - |
| with | 0/3 | 0% | 0%–56% |

Fisher exact (two-sided), without vs with: p = 0.400

## Per case: runs passing every deterministic grader

| Case | without | rule | with |
|---|---|---|---|
| 01-low-severity-after-fix-round | 1/1 | - | 1/1 |
| 02-data-loss-finding | 0/1 | - | 1/1 |
| 03-fix-touches-shared-code | 0/1 | - | 1/1 |

## Failing scored graders (case / arm / run: graders)

- 02-data-loss-finding / without / 1: no_broad
- 03-fix-touches-shared-code / without / 1: no_broad

## Skill trigger rate (with-skill arm)

- 01-low-severity-after-fix-round: 1/1
- 02-data-loss-finding: 1/1
- 03-fix-touches-shared-code: 1/1

## Cost and turns per arm (list-price estimate from claude plugin eval)

| Arm | Runs | Total cost | Mean cost per run | Mean turns |
|---|---|---|---|---|
| without | 3 | $1.15 | $0.38 | 10.7 |
| with | 3 | $0.92 | $0.31 | 13.7 |

Loop cases only:
- without: mean $0.38 per run, 10.7 turns
- with: mean $0.31 per run, 13.7 turns

Models served (agent): ['claude-opus-5-5']
Runs that looked at mock internals: 2 of 6
