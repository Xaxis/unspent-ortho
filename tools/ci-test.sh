#!/usr/bin/env bash
# tools/test.sh on GitHub's runners instead of this box (.github/workflows/test.yml):
#   tools/ci-test.sh FILTER [--ref BRANCH] [--parts N] [--repeat N] [--fixed-fps N]
# It tests what origin holds for BRANCH (default: this checkout's branch), so push
# first; it says so when that is not this checkout's HEAD, and `--same` makes that
# a failure. It waits for the run, prints every part's FAIL and summary lines, and
# exits 0 only when every part is green (exit 0, a "passed," line, no SCRIPT ERROR).
# Why: the box is shared and CPU-bound; a targeted run here took a heavy slot for
# minutes and timed differently from CI. Takes no heavy slot. --parts splits the
# filter's terms over runners; --repeat N chases a flake (N of N, or not).
set -euo pipefail
cd "$(dirname "$0")/.."
repo=Xaxis/unspent-ortho
filter=""; ref=""; parts=1; repeat=1; fps=""; same=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref=$2; shift 2 ;;
    --parts) parts=$2; shift 2 ;;
    --repeat) repeat=$2; shift 2 ;;
    --fixed-fps) fps=$2; shift 2 ;;
    --same) same=1; shift ;;
    -*) echo "ci-test: unknown option $1" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
[ -n "$filter" ] || { sed -n '2,3p' "$0" >&2; exit 2; }
ref=${ref:-$(git branch --show-current)}
[ -n "$ref" ] || { echo "ci-test: detached HEAD: pass --ref BRANCH" >&2; exit 2; }
gh_() { env -u GITHUB_TOKEN gh "$@"; }
remote=$(git ls-remote origin "refs/heads/$ref" | cut -c1-40)
[ -n "$remote" ] || { echo "ci-test: $ref is not on origin: push it first" >&2; exit 2; }
head=$(git rev-parse HEAD)
if [ "$remote" != "$head" ]; then
  echo "ci-test: origin/$ref is ${remote:0:8}, this checkout is at ${head:0:8}: testing ${remote:0:8}" >&2
  [ "$same" = 1 ] && exit 2
fi
out=$(gh_ workflow run test.yml --repo "$repo" --ref "$ref" -f filter="$filter" -f parts="$parts" -f repeat="$repeat" -f fixed_fps="$fps" 2>&1)
id=$(printf '%s\n' "$out" | grep -oE '/actions/runs/[0-9]+' | tail -1 | grep -oE '[0-9]+$' || true)
[ -n "$id" ] || { echo "ci-test: no run id in: $out" >&2; exit 2; }
echo "ci-test: run $id tests ${remote:0:8} ($parts part(s) x $repeat): https://github.com/$repo/actions/runs/$id"
# Bounded: a part's own limit is 60 min; queueing on a busy day adds to it.
deadline=$(( $(date +%s) + 120 * 60 ))
while :; do
  st=$(gh_ run view "$id" --repo "$repo" --json status,conclusion -q '.status + " " + .conclusion' 2>/dev/null || echo "unknown ")
  case "$st" in completed*) break ;; esac
  [ "$(date +%s)" -lt "$deadline" ] || { echo "ci-test: run $id still '$st' after 120 min"; exit 3; }
  sleep 20
done
# Each log line is JOB<TAB>STEP<TAB>TIMESTAMP TEXT; keep the job and the text.
gh_ run view "$id" --repo "$repo" --log 2>/dev/null \
  | awk -F'\t' '$3 ~ /FAIL |passed,|SCRIPT ERROR|LOAD FAIL|ci-test part/ { sub(/^[0-9TZ:.-]+ /, "", $3); print $1 " | " $3 }'
concl=${st#completed }
echo "ci-test: $concl"
[ "$concl" = success ]
