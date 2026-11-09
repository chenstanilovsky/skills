---
type: tool_used
tool: Agent
input_match: '"(?:description|subagent_type)"\s*:\s*"[^"]*(?:[Rr]eview|[Ss]keptic|[Aa]udit|[Cc]ritiq|[Aa]dversar|[Vv]erif|[Dd]ouble.check|[Vv]alidat(?!ion/))'
min: 0
max: 0
arm: both
---
No reviewer, skeptic or verifier subagent was launched (matched on the subagent's description or type). In this case a run may legitimately use reviewer subagents as its single full review instead of scripts/review.sh; such runs fail here and are hand-classified from the trace (one round of subagents and no review.sh or validate-full.sh counts as the single full run; subagents on top of review.sh or validate-full.sh count as a second one).
