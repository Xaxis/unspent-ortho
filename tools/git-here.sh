#!/usr/bin/env bash
# Run a git command ONLY if this is the worktree and branch you meant.
#
#   tools/git-here.sh <worktree-root> <branch> <git args...>
#   tools/git-here.sh "$PWD" my/branch commit -F msg -- src/thing.gd
#
# WHY THIS EXISTS. A session's shell can be relocated into ANOTHER worktree
# between one command and the next, and on some days between a check and the
# write it was guarding. It has put stray commits on four branches, run a
# `git add` of one builder's paths inside another's tree, and left an
# integrator unable to reach the main checkout at all. The usual guards do not
# hold:
#
#   - Checking `pwd` in an earlier call proves nothing: the move happens after.
#   - `git -C <path>` is refused outright when the sandbox believes the session
#     is somewhere else, so it cannot be used to aim at your own tree either.
#   - An inline `cd X && git ...` or `if [ ... ]; then git ...; fi` is refused
#     as too complex to verify.
#
# What works is this: ONE process that cds, asks git itself where it is and
# what branch it is on, and only then `exec`s the git you asked for. Nothing
# can be relocated between the check and the write because there is no gap --
# the exec replaces this process with git, in the directory already verified.
#
# Two belts, because they fail differently: the ROOT catches being in the wrong
# tree, and the BRANCH catches being in the right tree at the wrong commit
# (a worktree someone has since checked out elsewhere).
#
# The other guard worth knowing, which needs no script: limit a commit by
# pathspec -- `git commit -F msg -- <your files>`. In the wrong tree those paths
# have no changes, so it fails harmlessly instead of committing someone's work.
# Use both. This one refuses loudly; that one cannot do damage quietly.
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: tools/git-here.sh <worktree-root> <branch> <git args...>" >&2
  exit 2
fi

want_root="$1"; shift
want_branch="$1"; shift

cd "$want_root" || { echo "git-here: cannot enter $want_root" >&2; exit 1; }

have_root="$(git rev-parse --show-toplevel)"
have_branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$have_root" != "$want_root" ]; then
  echo "git-here REFUSED: wanted worktree $want_root, am in $have_root" >&2
  exit 1
fi
if [ "$have_branch" != "$want_branch" ]; then
  echo "git-here REFUSED: wanted branch $want_branch, HEAD is $have_branch" >&2
  exit 1
fi

exec git "$@"
