# CLAUDE.md — unspent-ortho

UNSPENT: a real-time action-survival game on a generated coast where half-broken
machines hunt the people living in the gaps. Godot 4.7, typed GDScript,
orthographic 3D, everything built in code. Every screen the player reads is one
hacked slate made of machine parts.

Read before working in an area:
- `docs/VISION.md`: the destination. `docs/ROADMAP.md`: what's next, in order.
- `docs/LOOK.md`: the look of record (lit, not drawn).
- `docs/DESIGN.md` (the game), `docs/STORY.md` (binding on every story line),
  `docs/LANDSCAPES.md` (per-landscape specs).
- A package's own file header states its contract. Headers can be wrong: check the
  code under them before relying on one.

Never make anything look like Minecraft or a voxel game. Every landscape must be
hauntingly beautiful and specific.

## The loop

```sh
tools/test.sh [filter]          # headless tests; filter is a "file:method" substring
tools/check.sh                  # the gate: test shards + real frames (needs memory, see below)
tools/shot.sh shots/x.png [...] # one rendered frame; options in src/boot_options.gd header
tools/shot.sh shots/g.png --scene=gallery [--filter=NAME]
tools/tour.sh tours/x.tour      # scripted real-input proof; each tour's header has its options
tools/canon.sh [--accept]       # canon frames vs the accepted set
tools/web.sh                    # export and boot the web build in headless Chromium
tools/deploy.sh [--prod]        # deploy to Vercel and prove it loads there
```

- **Look at the pictures.** After any visible change, shoot it and Read the PNG. A
  green test says nothing about how it looks.
- **Check memory before a full run:** `vm_stat | head -2`. Free pages × 16 KB under
  ~500 MB means a full suite gets killed; use `tools/test.sh FILTER` instead.
- **A test written to show a bug must fail first.** Put the bug back and watch it
  go red before you believe the fix.
- **Stage by name, never by coordinate** in tours and shots (`near KIND`,
  `place NAME`, `at prop:KIND`).
- After pulling, run `tools/_import.sh` before `godot --path .`, or a new
  `class_name` fails to parse.

## Code rules

- Typed GDScript (`untyped_declaration` is an error). No `.tscn` beyond
  `src/main.tscn`, no imported art or audio.
- Determinism: no `randf()`. Use `Rng.hash01(seed, x, y, salt)` or
  `Rng.make(seed, salt)`.
- Game logic lives in `src/core/` (pure, headless-testable). Systems are
  `src/systems/NN_name.gd`, auto-loaded in name order; never edit `game.gd` to add
  one.
- A landscape is one file in `src/content/biomes/`. Nothing outside it branches on
  a landscape by name; shared code reads `BiomeDef` declarations.
- Colour goes through `matter_albedo()`; nothing writes `ALBEDO` directly.
  Transparent world geometry needs an explicit `render_priority`, or it silently
  doesn't draw.
- A `class_name` must not shadow a native class or method name.
- **Worldgen changes move every seed.** Anything that changes what a seed makes,
  including the body of a `surface`/`scatter` recipe, bumps `WorldStamp.GEN` by
  hand and re-accepts `tests/biome/test_parity.gd`. Coordinate that with whoever
  owns the current GEN.
- Comments say why and give the contract. No narration, no history.

## Working alongside other sessions

- Several sessions and builders share this repo. Run `git worktree list` and
  `git status` before touching anything shared.
- One builder, one worktree, one branch. Never write in another session's
  worktree, commit on its branch, or delete it. Don't kill godot processes you
  didn't start.
- Builders branch from `origin/main`: `git fetch origin && git checkout -B <branch>
  origin/main`.
- Stage explicit paths. Commit with a pathspec (`git commit -F msg -- <paths>`),
  never `-a` or `add -A`. Use `tools/git-here.sh <root> <branch> <git args>` when
  your shell might be in another worktree.
- Never rebase, reset or force-push `main`.
- Scratch files and commit messages go in your session's scratchpad, not
  `/tmp/claude-501`.
- Send a peer measurements, not conclusions, and re-derive a peer's claim before
  building on it.

## Commits and shipping

Every commit is the owner's:

```sh
git -c user.name=Xaxis -c user.email=william.neeley@gmail.com commit -F msgfile -- <paths>
```

No `Co-Authored-By`, no generated-by line, no attribution of any kind. Messages lead
with why, in short sentences.

Remote: `github.com/Xaxis/unspent-ortho`. A push to main runs the CI gate and
deploys a preview. Production (`tools/deploy.sh --prod`) is deliberate.
`VERCEL_TOKEN` lives in `.env` and is never committed. With `gh`, use
`env -u GITHUB_TOKEN gh`.

`../unspent` is the old Unity attempt: mine it for mechanics numbers only. Never
port its story, dialogue or lore.
