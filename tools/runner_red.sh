#!/usr/bin/env bash
# Prove the test runner goes red when it should (tests/run.gd). Plants, runs,
# and takes away five things, one run each:
#   1. a test that passes, alone                 -> the runner must exit 0
#   2. a test whose code dies of a SCRIPT ERROR  -> it must print FAIL, exit 1
#   3. a test that boots a game and never ends it -> IT fails, by name, and the
#      test after it runs in a tree with no game in it
#   4. a src script that does not parse          -> load error, exit 1
#   5. a last test that lets go of a realm raise  -> the runner claims it before
#      it quits, so no worker is left in the pool (no "Pages in use" line)
# The first is the control: without it a runner that is always red would pass.
# Usage: tools/runner_red.sh    (exits 0 only if all five behave)
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
const Sx := preload("res://tests/save/save_fixture.gd")


func test_leaves_a_game() -> void:
	check(Sx.game(tree, ["--size=64"]) != null)


func test_then_finds_none() -> void:
	for n: Node in tree.root.get_children():
		check(n.get_script() == null or (n.get_script() as Script).get_global_name() != &"Game", "no game left over")
EOF
code=$(run)
if [ "$code" = 0 ] || ! grep -q "FAIL test_zz_runner_probe:test_leaves_a_game" "$log" || ! grep -q "left a game running" "$log" \
    || ! grep -q "ok   test_zz_runner_probe:test_then_finds_none" "$log"; then
  echo "runner_red: a test that left a game running was not red, or the next test found it (exit $code)"; grep "test_zz_runner_probe\|left a game" "$log"; fails=1
else
  echo "runner_red: leaked game red, and ended before the next test (exit $code)"
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
rm -f "$broken" "$broken.uid"

# Every game lets go of its realm raise as it ends (20_realms -> RealmWorlds.forget)
# and the raise runs on, halted, to the end of its stage. After a shard's last
# test comes only the quit, and a process torn down with a worker inside GDScript
# either faults or blocks for ever on the language's own lock: two CI shards sat
# an hour after their last "ok" until the job was cancelled.
cat >"$probe" <<'EOF'
extends TestCase
## Planted by tools/runner_red.sh; never committed.


func test_lets_go_of_a_raise() -> void:
	RealmWorlds.forget()
	RealmWorlds.settle()
	RealmWorlds.begin(90422, 1024, &"underground")
	OS.delay_msec(300)
	RealmWorlds.forget()
	check(RealmWorlds._orphan_running(), "the raise is still running when the test ends")
EOF
code=$(run)
if [ "$code" != 0 ] || ! grep -q "ok   test_zz_runner_probe:test_lets_go_of_a_raise" "$log" \
    || grep -q "Pages in use exist at exit in PagedAllocator: N16WorkerThreadPool5GroupE" "$log"; then
  echo "runner_red: the runner quit with a realm raise still in the pool (exit $code)"; grep "test_lets_go\\|PagedAllocator" "$log"; fails=1
else
  echo "runner_red: a raise left by the last test is claimed before the quit (exit $code)"
fi
rm -f "$log"
exit $fails
