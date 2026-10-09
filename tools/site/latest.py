#!/usr/bin/env python3
"""The site's release manifest, from the newest published GitHub release.

    tools/site/latest.py OUT.json     write it; exit 0 with no file when there is
                                      no published release yet

site/site.js reads it to fill the download cards, so the page always offers what
GitHub really holds: release assets carry their version in their names
(UNSPENT-<v>-macos-universal.zip), and a link written into the page by hand
would go stale with the next tag. Uses GH_TOKEN or GITHUB_TOKEN when set (the
unauthenticated API allows 60 calls an hour per address, which a CI runner's
shared address can spend).
"""
import json
import os
import sys
import urllib.error
import urllib.request

REPO = os.environ.get("UNSPENT_REPO", "Xaxis/unspent-ortho")
# Which asset is which system's (.github/workflows/release.yml, Package).
SUFFIX = {"macos": "-macos-universal.zip", "windows": "-windows-x86_64.zip", "linux": "-linux-x86_64.zip"}


def fetch(url: str):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "unspent-site"})
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: tools/site/latest.py OUT.json", file=sys.stderr)
        return 2
    try:
        rel = fetch("https://api.github.com/repos/%s/releases/latest" % REPO)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print("latest: no published release of %s yet; the site says so" % REPO)
            return 0
        raise
    builds = {}
    for a in rel.get("assets", []):
        for system, suffix in SUFFIX.items():
            if a["name"].endswith(suffix):
                digest = a.get("digest") or ""
                builds[system] = {
                    "name": a["name"],
                    "url": a["browser_download_url"],
                    "size": a["size"],
                    "sha256": digest[7:] if digest.startswith("sha256:") else "",
                }
    out = {
        "version": rel["tag_name"].lstrip("v"),
        "published": rel.get("published_at"),
        "url": rel["html_url"],
        "builds": builds,
    }
    with open(sys.argv[1], "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
    print("latest: %s, builds for %s" % (out["version"], ", ".join(sorted(builds)) or "nothing"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
