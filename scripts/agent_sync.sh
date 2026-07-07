#!/usr/bin/env bash
# Syncs live agent config files back into the repo's agent/ templates so
# fresh-machine seeds stay current, and reports installed Claude skills that
# no setup source covers.
#
# Default: show diffs, copy live files over the repo templates (commit after).
# --check: report drift and unmanaged skills as warnings only, always exit 0
#          (used by scripts/check.sh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

PAIRS=(
    "$HOME/.claude/CLAUDE.md|$ROOT_DIR/agent/CLAUDE.md"
    "$HOME/OPINIONS.md|$ROOT_DIR/agent/OPINIONS.md"
    "$HOME/VOICE.md|$ROOT_DIR/agent/VOICE.md"
    "$HOME/.no-mistakes/config.yaml|$ROOT_DIR/agent/no-mistakes.config.yaml"
)

drift=0
for pair in "${PAIRS[@]}"; do
    live="${pair%%|*}"
    repo="${pair##*|}"

    if [[ ! -f "$live" ]]; then
        warn "missing live file $live (run scripts/agent_setup.sh)"
        continue
    fi
    cmp -s "$live" "$repo" 2>/dev/null && continue

    drift=1
    if ((CHECK_ONLY)); then
        warn "agent template drift: $repo differs from $live (run scripts/agent_sync.sh)"
    else
        diff -u "$repo" "$live" 2>/dev/null || true
        cp "$live" "$repo"
        echo "Synced $live -> $repo"
    fi
done

# Skills in ~/.claude/skills that no agent_setup.sh source installs; either
# add them to agent/motive-skills.txt (if from the Motive repo) or wire a
# source into agent_setup.sh so fresh machines get them too.
managed=" skill-creator find-skills no-mistakes $(grep -vE '^[[:space:]]*(#|$)' "$ROOT_DIR/agent/motive-skills.txt" | tr '\n' ' ')"
for dir in "$HOME/.claude/skills"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" == *axi* ]] && continue
    [[ "$managed" == *" $name "* ]] && continue
    warn "skill $name is installed but not covered by agent_setup.sh"
done

if ((!CHECK_ONLY)) && ((!drift)); then
    echo "Agent templates are in sync."
fi
