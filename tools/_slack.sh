#!/usr/bin/env bash
# How much less of a processor a run is getting than it would on a quiet machine.
#
# A wave of builders puts this laptop past a load average of sixty, and then a
# shot that takes two seconds takes forty, and every tool that watches a clock
# starts failing for reasons that have nothing to do with the game. A timeout
# that fires for that is a timeout people learn to raise by hand and then stop
# believing. So the tools multiply theirs by this instead: unchanged on a quiet
# machine, honest on a busy one. tests/test_case.gd does the same for the test
# budgets (TestCase.machine_slack).
#
#   . tools/_slack.sh
#   secs="$(slack_secs 60)"

slack_factor() {
	local load cores
	if [ -r /proc/loadavg ]; then
		load="$(cut -d' ' -f1 /proc/loadavg)"
	else
		load="$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1}')"
	fi
	cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
	awk -v l="${load:-0}" -v c="${cores:-1}" 'BEGIN { s = (c > 0 ? l / c : 1); if (s < 1) s = 1; if (s > 8) s = 8; printf "%.2f", s }'
}


## Seconds to allow for something that takes $1 seconds on a quiet machine.
slack_secs() {
	awk -v b="${1:-60}" -v s="$(slack_factor)" 'BEGIN { printf "%d", b * s }'
}
