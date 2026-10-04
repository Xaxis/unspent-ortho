#!/usr/bin/env bash
# Prove the test runner goes red when it should (tests/run.gd). Plants, runs,
# and takes away seven things, one run each:
#   1. a test that passes, alone                 -> the runner must exit 0
#   2. a test whose code dies of a SCRIPT ERROR  -> it must print FAIL, exit 1
#   3. a test that boots a game and never ends it -> IT fails, by name, and the
#      test after it runs in a tree with no game in it
#   4. a src script that does not parse          -> load error, exit 1
#   5. a last test that lets go of a realm raise  -> the runner claims it before
#      it quits, so no worker is left in the pool (no "Pages in use" line)
#   6. a test that keeps 5000 WorldProps alive -> IT fails, by name, and the
#      tests after it are green, one that walked 5000 after an await included
#   7. a last test that leaves the shared bank baking -> the runner claims the
#      bakes and EXITS, on a pool shaped like CI's four threads
# The first is the control: without it a runner that is always red would pass.
# Usage: tools/runner_red.sh    (exits 0 only if all seven behave)
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

# A test that keeps the world's props as objects fails, by name, and the one after
# it does not. A grown world holds its props as table rows (tests/stream/
# test_prop_table.gd), and that file was the one that went red for 32,028 props a
# story test far earlier in the shard had kept (2026-10-03).
cat >"$probe" <<'PROBE'
extends TestCase
## Planted by tools/runner_red.sh; never committed.
static var kept: Array[WorldProp] = []


func test_keeps_props() -> void:
	for i in 5000:
		kept.append(WorldProp.new(i, PropKind.FIRE, Vector2(i, i), 0.0, 1.0))
	check(true)


func test_then_runs_clean() -> void:
	check(true)


# Walking props after an await keeps nothing: the runner lets go of a finished
# coroutine's frame, which Godot 4.7 otherwise holds until the next one ends.
func test_walks_after_a_frame() -> void:
	await tree.process_frame
	var n := 0
	for q: WorldProp in _views(5000):
		n += 1
	check(n == 5000)


static func _views(count: int) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for i in count:
		out.append(WorldProp.new(i, PropKind.FIRE, Vector2(i, i), 0.0, 1.0))
	return out
PROBE
code=$(run)
if [ "$code" = 0 ] || ! grep -q "FAIL test_zz_runner_probe:test_keeps_props" "$log" || ! grep -q "left 5000 WorldProps alive" "$log" \
    || ! grep -q "ok   test_zz_runner_probe:test_then_runs_clean" "$log" || ! grep -q "ok   test_zz_runner_probe:test_walks_after_a_frame" "$log"; then
  echo "runner_red: a test that kept 5000 props was not red by name, or a test after it was (exit $code)"; grep "test_zz_runner_probe\|WorldProps" "$log"; fails=1
else
  echo "runner_red: kept props red on the test that kept them (exit $code)"
fi

# The shared SoundBank outlives every game, and a game that ends leaves its
# bakes running for the next one (70_audio `_exit_tree`). On CI's four-thread
# pool only ONE low-priority task runs at a time, so a second bake waits in the
# pool's low-priority queue, and Godot's pre-exit (WorkerThreadPool::
# exit_languages_threads) only counts a worker idle when both queues are empty:
# the workers that looked first sleep uncounted, nobody wakes them, and the main
# thread waits for ever. Measured on CI 2026-09-28: every hung shard's main
# thread in a condition wait on the pool's task mutex, all four workers idle.
# The pool is shaped like CI's here (override.cfg), and the run gets a deadline.
cat >"$probe" <<'EOF'
extends TestCase
## Planted by tools/runner_red.sh; never committed.


func test_lets_go_of_bakes() -> void:
	var bank := SoundBank.shared()
	bank.threaded = true
	# Warm, as every bank is after the first game in a shard.
	bank._warm_world = true
	bank._warm_score = true
	bank.request(ScoreStems.key_for(&"coast", &"pad", 0), true)
	bank.request(&"alert_runner")
	bank.request(&"ui_move")
	bank._pumped_frame = -1
	bank.pump()
	check(bank._jobs.size() >= 2, "two bakes or more are on the pool when the test ends (%d)" % bank._jobs.size())
EOF
printf '[threading]\n\nworker_pool/max_threads=4\n' >override.cfg
trap 'cleanup; rm -f override.cfg' EXIT
tools/_import.sh >/dev/null 2>&1
perl -e 'alarm 120; exec @ARGV' godot --headless --path . -s tests/run.gd -- test_zz_runner_probe >"$log" 2>&1; code=$?
rm -f override.cfg
if [ "$code" != 0 ] || ! grep -q "ok   test_zz_runner_probe:test_lets_go_of_bakes" "$log" \
    || grep -q "Pages in use exist at exit in PagedAllocator: N16WorkerThreadPool4TaskE" "$log"; then
  echo "runner_red: the runner quit with the shared bank's bakes still in the pool (exit $code; 142 is the deadline)"; grep "test_lets_go\\|PagedAllocator\\|runner:\\|WorkerThreadPool:" "$log"; fails=1
else
  echo "runner_red: bakes the shared bank still holds are claimed before the quit (exit $code)"
fi
rm -f "$log"
exit $fails
