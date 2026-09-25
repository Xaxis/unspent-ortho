#!/usr/bin/env bash
# Prove the test runner goes red when it should (tests/run.gd). Plants, runs,
# and takes away three things, one run each:
#   1. a test that passes, alone                 -> the runner must exit 0
#   2. a test whose code dies of a SCRIPT ERROR  -> it must print FAIL, exit 1
#   3. a src script that does not parse          -> load error, exit 1
# The first is the control: without it a runner that is always red would pass.
# Usage: tools/runner_red.sh    (exits 0 only if all three behave)
set -uo pipefail
cd "$(dirname "$0")/.."
probe_dir="tests/zz_runner_red"
probe="$probe_dir/test_zz_runner_probe.gd"
broken="src/zz_runner_red_broken.gd"
cleanup() { rm -rf "$probe_dir" "$broken" "$broken.uid"; }
trap cleanup EXIT
mkdir -p "$probe_dir"
log="$(mktemp "${TMPDIR:-/tmp}/runner-red.XXXXXX")"
fails=0

run() { tools/test.sh "test_zz_runner_probe" >"$log" 2>&1; echo $?; }

cat >"$probe" <<'EOF'
extends TestCase
## Planted by tools/runner_red.sh; never committed.


func test_passes() -> void:
	check(true)
EOF
code=$(run)
if [ "$code" != 0 ] || ! grep -q "ok   test_zz_runner_probe:test_passes" "$log"; then
  echo "runner_red: CONTROL a passing test did not run green (exit $code)"; tail -5 "$log"; fails=1
else
  echo "runner_red: control green (exit 0)"
fi

cat >>"$probe" <<'EOF'


func test_dies_half_way() -> void:
	var n: Node = null
	n.get_name()
	check(true, "never reached")
EOF
code=$(run)
if [ "$code" = 0 ] || ! grep -q "FAIL test_zz_runner_probe:test_dies_half_way" "$log"; then
  echo "runner_red: a test that died of a SCRIPT ERROR was not red (exit $code)"; grep "test_dies_half_way" "$log"; fails=1
else
  echo "runner_red: script error red (exit $code)"
fi

cat >"$probe" <<'EOF'
extends TestCase
## Planted by tools/runner_red.sh; never committed.


func test_passes() -> void:
	check(true)
EOF
printf 'extends RefCounted\n\nfunc broken( -> void:\n\tpass\n' >"$broken"
code=$(run)
if [ "$code" = 0 ] || ! grep -q "LOAD FAIL res://$broken" "$log"; then
  echo "runner_red: a src script that does not parse was not red (exit $code)"; tail -5 "$log"; fails=1
else
  echo "runner_red: parse error red (exit $code)"
fi
rm -f "$log"
exit $fails
