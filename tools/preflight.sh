#!/usr/bin/env bash
# Before a branch is called ready: the cheap rules the CI gate keeps catching.
# Usage: tools/preflight.sh [extra test filter, comma-separated]
#
# One process, a few minutes, safe on a busy laptop. It is not the gate: it runs
# the tests that read the WHOLE TREE for a rule (a prop compared as an object, a
# whole-world reader missing from its list, a system with no feature map entry,
# a tour naming a frame it cannot hold, an untyped worker read, a room kind a
# list does not name), because a targeted run of the tests beside a change never
# reaches them. On 2026-09-27/28 six of eleven red gates were one of these, each
# costing a full gate to learn.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

# Every tracked script carries its tracked .uid (the same check tools/check.sh
# makes first).
missing="$(comm -23 <(git ls-files '*.gd' '*.gdshader' | sed 's/$/.uid/' | sort) <(git ls-files '*.uid' | sort))"
if [ -n "$missing" ]; then
  echo "TRACKED FILES WITH NO TRACKED .uid -- git add them:"; echo "$missing" | sed 's/\.uid$//; s/^/  /'; fail=1
fi

fm=~/.claude/claude-core/bin/featuremap
if [ -x "$fm" ]; then "$fm" check || fail=1; fi

rules="test_prop_identity,test_whole_world_readers,test_feature_map,test_tour_claims,test_worker_types,test_no_unique_names,test_stand_at,test_room_loot,test_rooms,test_names,test_cost_bars"
# Every PropKind at once: a kind appended must be grown somewhere (or listed as
# set down in play), give something or say why not, and be drawn above the pen.
# land/raids went red on all four with one new kind; about 100 s of the run.
rules="$rules,test_world_gen:test_every_prop_kind_and_ground_is_placed,test_world_gen_works:test_every_landscape_holds_its_own_works,test_signature_takes,test_dark_floor:test_no_prop_is_drawn_below_the_ink_floor"
[ -n "${1:-}" ] && rules="$rules,$1"
log="$(mktemp "${TMPDIR:-/tmp}/unspent-preflight.XXXXXX")"
tools/test.sh "$rules" >"$log" 2>&1; code=$?
grep -E "FAIL|^\s{7}|SCRIPT ERROR|LOAD FAIL|passed," "$log"
if [ "$code" != "0" ] || grep -qE "SCRIPT ERROR|LOAD FAIL" "$log" || ! grep -qE "passed," "$log"; then fail=1; fi
rm -f "$log"

if [ $fail -ne 0 ]; then echo "PREFLIGHT FAILED"; exit 1; fi
echo "PREFLIGHT OK"
