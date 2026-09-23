#!/usr/bin/env bash
# Put the web build on Vercel and prove it runs there.
#   tools/deploy.sh                 a preview URL, for looking at
#   tools/deploy.sh --prod          the one the domain points at
#   tools/deploy.sh --no-export     deploy what is already in build/web
#   tools/deploy.sh --no-check      skip the browser proof (not advised)
#   tools/deploy.sh --dir=DIR       deploy a build from elsewhere (a kept build: build/kept/<id>/web);
#                                   implies --no-export
#
# The deploy is recorded in the build's build.json (tools/export.sh writes it), so
# dev mode's shelf says where a build went and whether it was production. The
# build.json itself is not deployed: it names the configuration it was made from.
# Needs VERCEL_TOKEN, from .env here or from the environment (CI). Never commit it.
#
# The build goes under /b/<sha>/ and / redirects to it, so every file can be
# cached forever and a player who comes back after a deploy can never end up
# running a new pack against an old engine. The threaded build needs the page to
# be cross-origin isolated, so the headers below are not optional: without them
# the engine refuses to start, which is why the proof at the end loads the real
# URL in a real browser rather than trusting that we sent them.
set -uo pipefail
cd "$(dirname "$0")/.."

prod=0; do_export=1; do_check=1; dir=build/web
for a in "$@"; do
  case "$a" in
    --prod) prod=1 ;;
    --no-export) do_export=0 ;;
    --no-check) do_check=0 ;;
    --dir=*) dir="${a#--dir=}"; do_export=0 ;;
    *) echo "deploy: unknown option $a"; exit 2 ;;
  esac
done

[ -f .env ] && set -a && . ./.env && set +a
if [ -z "${VERCEL_TOKEN:-}" ]; then echo "deploy FAILED: no VERCEL_TOKEN (.env or environment)"; exit 1; fi
PROJECT_ID="${VERCEL_PROJECT_ID:-prj_tmaEekddT8BxG8axEbV9ubdirCje}"
ORG_ID="${VERCEL_ORG_ID:-team_pUDLCiJEYW3wgGiFmRXc4ET3}"

if [ "$do_export" = 1 ]; then
  tools/export.sh web || exit 1
fi
[ -f "$dir/index.html" ] || { echo "deploy FAILED: no build in $dir (tools/export.sh web)"; exit 1; }

sha="$(git rev-parse --short HEAD)"
[ -n "$(git status --porcelain --untracked-files=no)" ] && sha="$sha-dirty"
# A stamped build is served under the commit it was made from, not the one checked
# out now, and its configuration and a hash of its stamp: /b/ is cached for a year,
# so two builds of one commit (playtest, then release) must never share a path.
if [ -f "$dir/build.json" ]; then
  stamped="$(python3 -c '
import hashlib, json, sys
raw = open(sys.argv[1], "rb").read()
d = json.loads(raw)
parts = [d.get("commit", "") + ("-dirty" if d.get("dirty") else "")]
if d.get("config"): parts.append(d["config"])
keep = {k: d.get(k) for k in ("config", "settings", "built_at", "commit", "target", "template")}
parts.append(hashlib.sha1(json.dumps(keep, sort_keys=True).encode()).hexdigest()[:6])
print("-".join(p for p in parts if p))' "$dir/build.json" 2>/dev/null)"
  [ -n "$stamped" ] && sha="$stamped"
fi

rm -rf .vercel/output
mkdir -p ".vercel/output/static/b/$sha"
# The .br and .gz siblings are for a server that negotiates; Vercel does its own.
for f in "$dir"/*; do
  case "$f" in *.br|*.gz|*/build.json) continue ;; esac
  cp "$f" ".vercel/output/static/b/$sha/"
done

cat > .vercel/output/config.json <<EOF
{
  "version": 3,
  "routes": [
    { "src": "/", "status": 308, "headers": { "Location": "/b/$sha/" } },
    { "src": "/(.*)",
      "headers": {
        "Cross-Origin-Opener-Policy": "same-origin",
        "Cross-Origin-Embedder-Policy": "require-corp",
        "Cross-Origin-Resource-Policy": "same-origin",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer"
      },
      "continue": true },
    { "src": "/b/([^/]+)/(.*)",
      "headers": { "Cache-Control": "public, max-age=31536000, immutable" },
      "continue": true },
    { "src": "/b/([^/]+)/?$", "dest": "/b/\$1/index.html" },
    { "handle": "filesystem" },
    { "src": "/(.*)", "status": 308, "headers": { "Location": "/b/$sha/" } }
  ]
}
EOF

mkdir -p .vercel
printf '{"projectId":"%s","orgId":"%s"}\n' "$PROJECT_ID" "$ORG_ID" > .vercel/project.json

echo "deploy $sha -> vercel ($([ "$prod" = 1 ] && echo production || echo preview))"
log="$(mktemp "${TMPDIR:-/tmp}/unspent-deploy.XXXXXX")"
# The token rides in the environment (the CLI reads VERCEL_TOKEN), never on the
# command line: an argument is readable by every `ps` on the machine for as long
# as the deploy runs, which is how another session came to see it.
export VERCEL_TOKEN
if [ "$prod" = 1 ]; then
  npx --yes vercel@48 deploy --prebuilt --prod --yes >"$log" 2>&1
else
  npx --yes vercel@48 deploy --prebuilt --yes >"$log" 2>&1
fi
code=$?
url="$(grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app' "$log" | tail -1)"
if [ $code -ne 0 ] || [ -z "$url" ]; then
  tail -20 "$log"; echo "deploy FAILED"; rm -f "$log"; exit 1
fi
rm -f "$log"
echo "deploy ok $url"
if [ -f "$dir/build.json" ]; then
  python3 - "$dir/build.json" "$url" "$prod" <<'PY' || true
import json, sys, time
path, url, prod = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
d = json.load(open(path))
d.setdefault("deploys", []).append({"url": url, "production": prod, "at": int(time.time())})
json.dump(d, open(path, "w"), indent="\t", sort_keys=True)
PY
fi

if [ "$do_check" = 1 ]; then
  # The same proof a local build gets, against what the host actually serves:
  # the title, a new game played through the loading page, and a reload that
  # must find the save still there.
  if [ ! -d tools/web/node_modules/playwright ]; then
    npm install --prefix tools/web --no-audit --no-fund >/dev/null || { echo "deploy FAILED: npm install"; exit 1; }
    npx --prefix tools/web playwright install chromium-headless-shell >/dev/null 2>&1 || true
  fi
  mkdir -p shots/export
  node tools/web/web.mjs --url="$url" --out=shots/export/deploy --play --reload || {
    echo "deploy FAILED: the build does not run at $url"; exit 1; }
fi
echo "deploy done $url"
