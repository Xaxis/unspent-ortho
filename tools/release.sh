#!/usr/bin/env bash
# Cut a release of what main holds, and see it through to working downloads:
#   tools/release.sh            the next patch version (0.1.3 after 0.1.2; 0.1.0 if none)
#   tools/release.sh 0.2.0      that version
# It tags origin/main's head only: main only ever moves to a gated head, and that
# head's gate run must be green. The tag runs .github/workflows/release.yml, which
# builds all four, boots each on its own OS, publishes the release, checks every
# download answers in full and redeploys unspent.world; this waits for that run
# and then reads the site's /releases/latest.json until it names the version.
# Why: the downloads on unspent.world are only as good as the last release, and a
# release cut by hand from a branch, or never cut, left the site offering nothing.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=Xaxis/unspent-ortho
site="${UNSPENT_DOMAIN:-https://www.unspent.world}"
gh_() { env -u GITHUB_TOKEN gh "$@"; }

git fetch -q origin main --tags
head=$(git rev-parse origin/main)
# No tags yet is an empty answer, not a failure (grep finding nothing exits 1).
last=$(git tag --list 'v[0-9]*' --sort=-v:refname | { grep -v -- - || true; } | head -1)
if [ $# -gt 0 ]; then
  v="${1#v}"
elif [ -z "$last" ]; then
  v=0.1.0
else
  IFS=. read -r ma mi pa <<<"${last#v}"
  v="$ma.$mi.$((pa + 1))"
fi
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "release: '$v' is not a version"; exit 2; }
git rev-parse -q --verify "refs/tags/v$v" >/dev/null && { echo "release: v$v exists already"; exit 1; }
[ -n "$last" ] && [ "$(git rev-list -n1 "$last")" = "$head" ] && { echo "release: $last already is main's head ${head::8}"; exit 1; }

gate=$(gh_ run list --repo "$repo" --workflow gate.yml --commit "$head" --json conclusion,status --jq '[.[] | select(.status == "completed")][0].conclusion // "none"')
[ "$gate" = success ] || { echo "release: main's head ${head::8} has no green gate run ($gate); land a gated head first"; exit 1; }

echo "release: v$v from main ${head::8} (last ${last:-none})"
git -c user.name=Xaxis -c user.email=william.neeley@gmail.com tag -a "v$v" -m "UNSPENT $v" "$head"
git push -q origin "v$v"

# The tag's run: wait for it to appear, then for it to end.
id=""
for _ in $(seq 1 30); do
  id=$(gh_ run list --repo "$repo" --workflow release.yml --event push --json databaseId,headBranch --jq ".[] | select(.headBranch == \"v$v\") | .databaseId" | head -1)
  [ -n "$id" ] && break
  sleep 10
done
[ -n "$id" ] || { echo "release FAILED: no release run started for v$v"; exit 1; }
echo "release: run $id (https://github.com/$repo/actions/runs/$id)"
gh_ run watch "$id" --repo "$repo" --interval 60 --exit-status > /dev/null || { echo "release FAILED: run $id"; gh_ run view "$id" --repo "$repo" | tail -20; exit 1; }

# A pre-release is published but never the latest, and the site keeps the last one.
[[ "$v" == *-* ]] && { echo "release done: v$v published as a pre-release"; exit 0; }
# The site takes the release from the deploy the run dispatched.
for _ in $(seq 1 60); do
  got=$(curl -s "$site/releases/latest.json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null || true)
  [ "$got" = "$v" ] && { echo "release done: v$v on $site (downloads for $(curl -s "$site/releases/latest.json" | python3 -c 'import json,sys; print(", ".join(sorted(json.load(sys.stdin)["builds"])))'))"; exit 0; }
  sleep 30
done
echo "release FAILED: $site/releases/latest.json still says '${got:-nothing}', not $v"
exit 1
