---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?validate-once"'
min: 1
---
Indicator only (with-only): the validate-once skill was loaded. Not scored. In this case the expected behaviour is that it does NOT load (a question with no change to check), so a pass here is read as an unneeded trigger.
