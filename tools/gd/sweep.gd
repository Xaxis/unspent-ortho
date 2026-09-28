extends SceneTree
## THE MATCHUP SWEEP, over the shoulder: every weapon against every common
## machine alone, and against the crowds that make a wall, fought by the
## shoulder reader (tests/fight/shoulder_reader.gd: what a player over the
## shoulder knows). A measurement to re-run after every tuning pass, never a
## gate: it is off CI, and tools/sweep.sh bounds it.
##
##   tools/sweep.sh [--singles|--crowds] [--crowd=N] [--reader=human[:SEED]] [--weapons=a,b] [--machines=a,b] [--starts=N]
##
## SINGLES: one machine roused five tiles off (test_crowd_reader.gd `gate`),
## 20 wick, 90 s, START starts round the compass. A pairing is TRIVIAL when
## every start is won with nothing lost inside TRIVIAL_S.
## CROWDS: CROWDS side by side five tiles off, 8 starts, 90 s.
## --reader=human[:SEED] fights them with the human reader (Reader.human: a
## 250-450 ms reaction, 10% of tells misread, 1 in 8 strikes whiffed), the one
## balance targets are judged by; without it, the perfect reader every test uses.
## Every row is printed, then the summary: singles trivial %, 3-cutter wins by
## weapon line, each crowd's mean health lost and wins.

# The sweep is tools/gd/sweep_run.gd, loaded once the autoloads stand: the
# fight's scripts name them (Events), and a -s script is compiled before they
# are registered.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var s: GDScript = load("res://tools/gd/sweep_run.gd")
	s.call(&"run", OS.get_cmdline_user_args())
	quit()
