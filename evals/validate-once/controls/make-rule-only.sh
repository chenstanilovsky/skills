#!/bin/bash
# Builds the "rule only" control arm: a plugin with no components whose eval cases are exact
# copies of ../<case>/ with the validate-once rule added as a system-prompt line
# (execution.append_system_prompt). Nothing else changes. Run it with --ablation none.
#
#   evals/validate-once/controls/make-rule-only.sh <out-dir>
#   claude plugin eval <out-dir> --ablation none --scaffold ...
#
# The output must live outside evals/validate-once/, because claude plugin eval collects every
# case.yaml below its eval dir.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$(cd "$here/.." && pwd)"
out="${1:?usage: make-rule-only.sh <out-dir>}"
case "$(cd "$(dirname "$out")" && pwd)/$(basename "$out")/" in "$src"/*) echo "out-dir must be outside $src" >&2; exit 2;; esac
rm -rf "$out"
mkdir -p "$out/.claude-plugin" "$out/evals"
cat > "$out/.claude-plugin/plugin.json" <<'JSON'
{"name": "validate-once-rule-only", "version": "0.0.0", "description": "No components. Control arm for the validate-once eval: the rule as one system-prompt line."}
JSON
cp -R "$src/_shared" "$out/evals/_shared"
# The rule, verbatim from the skill (first paragraph after the title).
rule="$(awk '/^# Validate once/{f=1;next} f&&NF{print;exit}' "$src/../../skills/validate-once/SKILL.md")"
[ -n "$rule" ] || { echo "could not read the rule from SKILL.md" >&2; exit 1; }
n=0
for d in "$src"/*/; do
  [ -f "$d/case.yaml" ] || continue
  name="$(basename "$d")"
  cp -R "$d" "$out/evals/$name"
  rm -f "$out/evals/$name/graders/skill_fired.md"   # indicator only; nothing to fire in this arm
  python3 - "$out/evals/$name/case.yaml" "$rule" <<'PY'
import json, sys
path, rule = sys.argv[1], sys.argv[2]
lines = open(path).read().split("\n")
assert not any("append_system_prompt" in l for l in lines), "case already sets append_system_prompt"
idx = [i for i, l in enumerate(lines) if l.rstrip() == "execution:"]
assert len(idx) == 1, "expected one 'execution:' line"
lines.insert(idx[0] + 1, "  append_system_prompt: " + json.dumps(rule))
open(path, "w").write("\n".join(lines))
PY
  # Prove nothing else changed.
  diff <(grep -v '^  append_system_prompt: ' "$out/evals/$name/case.yaml") "$d/case.yaml" >/dev/null \
    || { echo "unexpected case.yaml difference in $name" >&2; exit 1; }
  n=$((n + 1))
done
echo "rule-only control: $n cases in $out"
