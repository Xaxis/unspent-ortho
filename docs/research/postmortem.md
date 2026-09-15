# UNSPENT post-mortem: why the agent process was slow

Read-only investigation of `~/Projects/unspent` and its worktrees (`~/Projects/unspent-wt/`), 2026-09-15. No
gates, builds or Unity were run.

**Sources.** `git log --numstat` for all 918 commits on local `main` (09-04 08:14 to 09-14 19:50); the current
tree and `.claude/`; the design docs and script header comments; capture shots; and the Unity/player logs in
`/tmp`.

**Method.** I labelled each commit subject by hand against its per-path diff mix. The buckets are judgement
calls, so treat every percentage as ±3 points.

## 0. Verdict

1. **Checking the game became the work.**
   - 25.6% of commits built instruments: gates, lints, probes, harnesses.
   - 11.9% were process: locks, landing, worktrees, commit tools, measurement lessons.
   - 5.3% repaired damage agents did to each other.
   - In the last 308 commits, tooling plus process reached 47%.
   - `tools/` (76k lines) is now larger than the game code (60k).
2. **Getting from an edit to evidence took 15-45 minutes, one job at a time.**
   - A capture: 15-20 min behind a machine-wide lock.
   - The domain suite: 16-33 min behind a second lock.
   - The landing ladder: 25-43 min behind a third lock, re-run after every lost push race.
   - The agents said so: "The only way to look at the game took fifteen minutes, so nobody looked" (66e1ee65).
3. **The premise changed about six times in 11 days.** Each change stranded tested systems no player could
   reach, plus docs arguing for the old game.
4. **Many agents shared one checkout and one index for 7 days.** The result was 49 repair commits, a 547-line
   commit tool, four lock systems, and today 24 unlanded commits across 8 worktrees (28 GB).
5. **Everything existed twice and drifted silently.**
   - Content lived in two trees.
   - Art was a generator, a PNG in LFS, and a Unity `.meta`.
   - Docs described intent, not state.
   - Every copy needed a gate, and the gates needed gates: "The tool for finding checks that cannot fail
     contained a check that could not fail".
6. **The game is not yet fun or legible** (§5).

## 1. The numbers

### 1.1 Commits per day

Key: G gameplay/content (incl. fixes), A art/audio, E engine/platform, T tests only, L tooling/gates/lints/probes,
D design docs, R repairs/reverts, P process/meta.

| Day | Commits | G | A | E | T | L | D | R | P |
|---|---|---|---|---|---|---|---|---|---|
| 09-04 | 64 | 27 | 4 | 16 | 0 | 5 | 12 | 0 | 0 |
| 09-05 | 48 | 20 | 17 | 1 | 0 | 4 | 4 | 1 | 1 |
| 09-06 | 2 | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| 09-07 | 62 | 22 | 20 | 4 | 0 | 16 | 0 | 0 | 0 |
| 09-08 | 63 | 11 | 15 | 0 | 0 | 24 | 3 | 1 | 9 |
| 09-09 | 265 | 46 | 60 | 6 | 8 | 64 | 21 | 26 | 34 |
| 09-10 | 211 | 43 | 25 | 6 | 8 | 56 | 17 | 11 | 45 |
| 09-11 | 70 | 30 | 7 | 1 | 1 | 23 | 2 | 4 | 2 |
| 09-12 | 66 | 19 | 9 | 1 | 2 | 14 | 7 | 3 | 11 |
| 09-13 | 16 | 5 | 2 | 0 | 0 | 6 | 1 | 0 | 2 |
| 09-14 | 51 | 6 | 5 | 5 | 3 | 22 | 2 | 3 | 5 |

### 1.2 All 918 commits

| Bucket | Count | % | Representative subjects |
|---|---|---|---|
| Tooling/gates/lints/probes | 235 | 25.6 | "An accumulator that starts at the pass mark can only print the pass mark"; "The census prints a route hash, because the walk is steered by what it measures"; "Eight art checks were green, cited as authority, and never run" |
| Player-visible gameplay/content | 229 | 24.9 | "The road closes, the coast has to feed you, and the fail state is his life"; "Escape meant four different things, and one of them was silence"; "The workbench paid you a coin every time you made something" |
| Art/audio | 165 | 18.0 | "Four of every ground tile, so a field stops being wallpaper"; "Twelve machines were one flat violet box"; "A gull was arriving as loud as thunder overhead" |
| Process/meta | 109 | 11.9 | "The suite lock released whoever held it, not whoever set it, and three ran at once"; "A private index alone deletes other people's commits"; "A measurement of nothing is shaped exactly like a measurement" |
| Design docs | 69 | 7.5 | "The subject is gone, and so is every document built on it"; "The design doc argued against the game the owner asked for, and said so nowhere" |
| Repairs/reverts/fixups | 49 | 5.3 | "HEAD does not compile: half a rename…"; "Put back the ten cuts of weed my last commit deleted"; "Fourteen sources whose meta files never landed with them" |
| Engine/platform | 40 | 4.4 | "Unity becomes a renderer: one scene, and the world is content"; "Game.cs was 3,643 lines and every engine lane collided in it" |
| Tests only | 22 | 2.4 | "Twenty-two of 752 tests are 59% of the suite" |

**G overstates new play.** 95 of the 229 G subjects describe a defect ("was", "never", "could not",
"nothing"). Those commits repair something built wrong or built unreachable.

**The mix got worse over time.** L+P was 27% of commits 1-300 and 47% of commits 611-918; art fell from 22% to 9%.

**Day 1 was the most productive day.** In about 9 hours (commits 11-45), with almost no gates, the project
went from scaffold to a playable, deployed slice: battle, town, save, music, title. The owner rejected it on
design grounds, not on speed.

**Parallel agents committed in bursts.** The peak was 24 commits in one 10-minute window (09-09 17:00).
Counting only gaps under 1 h, the 252-hour span had about 96 active hours.

### 1.3 Where the lines are (current tree)

| Area | Lines | Notes |
|---|---|---|
| `Code/Engine` | 29,549 | pure C#, 0 `using UnityEngine` |
| Unity side (`Game/UI/Runtime/Editor`) | 30,768 | ~7.7k is probes/dev UI (`AutoCapture*` 5,878, `DevView` 1,044, `FiguresView` 770) |
| `Tests` | 28,042 | 752 tests: 533 run in 6 s; 22 take 59% of a 33-min suite |
| `tools/` | 75,986 | 113 entries, 52 `lint-*`, 21 `check.d` steps |
| content source `projects/unspent/content` | 18,920 | JSONC + `.usp` |
| content mirror `StreamingAssets/content` | 18,973 | the same content again |
| `docs/` | 11,730 | §7a failure taxonomy is ~970 lines |
| `.claude/` + `CLAUDE.md` | 2,524 | |
| commit messages | 1.72 MB / 304k words | 2.3× all docs (132k words); ~330 words per commit |

**Inside `tools/`:** art generators 33.6k, audio generators 5.7k, lints and gates 17.9k, dev apps (world builder,
story studio, text player, maps) 8.7k, capture harness 3.9k (`assert-run.sh` alone 3.4k), other 6.2k.

**Churn over history** (excluding PNG, scenes, `.meta`): tools +88k/-11k, game code +81k/-20k, content +39k/-17k
**and its mirror +38k/-15k**, tests +32k/-4k, docs +21k/-9k.

**Tools vs game code at end of day:** 09-04 3.9k/7.9k; 09-08 25.9k/28.6k; 09-09 43.6k/41.4k (tools pass code);
09-14 76.0k/60.3k. From 09-11 to 09-14, game code grew 5.9k lines while tools grew 14.7k.

Verification and process code totals about 75k lines: tests, lints, capture, in-game probes, dev apps, other
tools and `.claude`. Shipping game code is about 53k, or 92k if you count the art and audio generators.

## 2. Why it was slow

### 2.1 Feedback-loop latency

| Change | Path to evidence | Measured cost (source) |
|---|---|---|
| Engine rule | `test-domain.sh` | 16 m 34 s (CLAUDE.md); "about 33 minutes" (check.sh); a 32 m 48 s run. `--quick` (6 s) arrived only on day 11 |
| Content | mirror hook to StreamingAssets; `lint-content.sh` via `dotnet run` | "just after an Engine edit its answer may be one build behind"; Bash deletes and renames are not mirrored |
| Unity-side C# | `typecheck-unity.sh` | compile only, behind a lock ("cost a 20-minute run and a false failure") |
| Anything visible | `capture.sh`: export lint, typecheck, several batch-mode Unity launches, scripted tour | 15-20 min under a machine-wide lock; the tour alone ran 559 s |
| One frame | `frame.sh x y` | ~20 s, but only from the last build; added on day 8 |
| Art | Python generator → `export.py` → PNG in LFS → Unity import → `.meta` slicing → build → capture | a stale export refuses capture: "CAPTURES ARE BLOCKED FOR EVERYONE" |
| Landing | `land.sh`: rebase, full ladder, push, retry ×3 | 25-43 min ladder. "Three lands died at minute 43 on something minute 10 already knew." One lane ran 26 m, 25 m, then 1 h 07 m, all green, and landed nothing. One branch burned 100 min "bought by contention." One lander sat wedged for 2 h 14 m |
| Web | `build-web.sh` (~3 min), Vercel, puppeteer gate | "Every deploy since the ignore file shipped a game with no game in it"; "The deploy gate passed on a black screen"; a wrong author fails silently (`seat block`) |

**Unity's domain reload was not the bottleneck.** The logs show 1-1.7 s per reload. The cost came from four
other things:
- batch-mode cold starts;
- a 3.1 GB `Library` per worktree;
- an editor lockfile that forbids two Unity processes on one project;
- a scripted tour standing in for a person pressing Play.

Nobody iterated in play mode.

### 2.2 Verification became the product

**Every gap grew into a chain of work.** A gap became a gate. The gate then failed in a new way: green over an
empty set, a tautology, or reading the wrong copy. That failure became a §7a row and a commit essay. §7a now
names 57 shapes, e.g. "The gate that improves as the fault gets worse".

**The volume shows it.**
- 151 of 918 subjects (16%) are about a gate, lint, check, probe, census or measurement.
- The last tour logged about 550 check lines under 63 `[…Check]` tags.

**None of those checks looked at the screen.** Twenty-odd green runtime assertions missed a grey slab over the
middle of the screen for about a week: "none of them asked what the screen looked like. The owner found it by
playing the game" (563dc916).

**The Stop hook made slow gates mandatory.** It sends an agent back until `test-domain` or `typecheck` has
passed since the agent's last edit. So a 16-33 min suite became the price of saying "done" on any engine or
content change.

### 2.3 Concurrency tax

**Shared checkout until 09-11.** Two subjects from that period: "Photograph HEAD, not whatever twenty-three
agents have half-written", and "721 commits in seven days, nineteen of them putting back somebody else's
work". My count is 41 repair commits before worktrees (5.6%) and 8 after (4.3%).

**The fixes were more process.**
- Scripts: `commit-mine.sh` (547 lines), `guard_git.py` (460, runs on every Bash call), `wt.sh` (459),
  `land.sh` (349).
- Locks for the suite, landing, capture and typecheck.
- Helpers: `detach.sh`, `watchdog.sh`, three `prove-*-lock.sh`.

The locks then grew their own bugs: "released whoever held it, not whoever set it, and three ran at once"; "A
wedged suite held the lock all night".

**The widest changes could not land.** From `land.sh`: "The branch most worth gating thoroughly is the one
structurally least able to land … and it gets worse with every agent added."

**Work is stranded today.** There are 8 worktrees (28 GB). Four of them hold 24 unlanded commits, and one has
14 dirty files. Local `main` is 7 commits behind origin. `Game.cs` reached 3,643 lines ("every engine lane
collided in it") and `AutoCapture` reached 5,688.

### 2.4 Two copies of everything

**Content.** The tests read `projects/unspent/content/`; the game reads `StreamingAssets/content/`. Three
subjects show the cost:
- "325 tests read one copy of the content and the game ships the other"
- "The game shipped 47 items while the tests validated 58"
- "The bailiff fix went to the copy the game ships and not the copy the tests read"

StreamingAssets holds one game at a time, so adding a second project made "the ladder answer about two
different games".

**Art.** Generator, PNG and `.meta` slicing must all agree:
- "A generated PNG conflicts on every lane"
- "Eight new tiles grew the sheet a row and the slicing still cut the old one"
- "Every building in a clean build was cut from the wrong row"
- six commits about missing `.meta` files

**Constants and ports.** "Sixteen world constants in seven files". "Forty-nine tools each worked out where the
repository is". A JS port of the C# generator (`tools/builder/verify.js`) needed its own parity gates.

**Docs vs reality.**
- A design doc argued against the owner's game.
- Rulings were still listed as unbuilt after they were built.
- `09-ART-BIBLE.md` §1 still says 384x216.
- CLAUDE.md says attribution "had to be stripped out of history", yet 441 commits still carry
  `Claude-Session:` trailers.

### 2.5 Scope thrash

| When | Premise |
|---|---|
| 09-04 am | EarthBound-style turn-based RPG teaching money (Bitcoin); prologue slice; 2-2.5 year plan |
| 09-04 17:51 | **Reset.** Owner: *"literally every aspect of the game is very very very very bad"*. Engine-first, content as data, authored towns |
| 09-05 09:37 | "An open world, because you said sandbox": generated world |
| 09-09 08:22 | Owner: *"you're not even close to having built a good game yet"*. "Everything is built except a reason to want any of it"; the road becomes the spine |
| 09-10 20:06 | Rulings 1-6: Zelda real-time combat, no menus, nothing to do with Bitcoin, generated world is the game. 12 docs (3.2k lines) deleted |
| 09-11 | Rulings 7-9: machines are predators; survival/crafting pillar; real-time clock (*"completely baseless and idiotic"*) |
| 09-14 | "A game is a directory": engine as product, second project `bare`, 6 more docs deleted |

**Each reversal left debris.**
- "The live game was the deleted one."
- "The deleted game was still talking."
- "The one authored room a player can reach was still the deleted game."
- "Stand goes back in the machine's menu: I overruled a better design than mine" was committed twice.

On day 11 the agents started generalising the engine for a second game, while the first game was still not
fun.

### 2.6 Built, tested, unreachable

"Built, tested, and nobody can get to it -- four times, one shape" (28a52720). Examples:
- a creature layer whose only callers were tests;
- stone circles no one could enter;
- 13 of 23 sprite columns that nothing selects;
- "The threat engine resolved encounters no player could reach";
- "A fight has never begun in a rendered frame, because OpenBout had no caller";
- "Five machines stood on that coast and the player met none of them".

Their own diagnosis: "a test constructs the thing it tests and therefore supplies a caller." Unit-test greens
were read as "feature done."

### 2.7 Nobody looked, not even the robot

The newest capture (worktree `cast`, 09-14 23:35) produced 64 shots.
- **In 49 of the 60 in-world shots a dialogue box is open, and 47 were taken at the same tile (-462,39).**
- Shots named `wood`, `rock`, `mapfar`, `struck` and `beast-dead` all show the same field and the same
  conversation.
- A 09-12 shot named `19-machines-a` shows a stone ring and no machines.

The tour wedged early and kept photographing. This exact class of bug had been "fixed" before: "Six of
seventeen shots were named for screens the run never reached".

## 3. What `.claude/` costs each change

**Doctrine loaded per session: about 8k tokens.**
- `CLAUDE.md`: 285 lines covering 9 rulings, worktree/landing law and measurement discipline.
- Path-scoped rules: art 69 lines, measurement 61, plus engine, unity, content and audio.
- One agent file of 73-96 lines.
- Skills: `land`, `prove-gate`, `content-edit`, `capture`, `deploy`.

**Hooks.**

| Event | Hook | Effect |
|---|---|---|
| SessionStart | `session_brief.py` | session briefing |
| PreToolUse(Bash) | `guard_git.py` | refuses add, commit, checkout, restore, stash and rebase in the shared checkout |
| PreToolUse(Agent) | `guard_agent.py` | refuses an unisolated builder |
| PostToolUse(Edit/Write) | `record_edit.py`, `mirror_content.py` | records the edit and mirrors content |
| Stop / SubagentStop / TeammateIdle | `stop_gates.py` | blocks "done" until the gates have passed |
| WorktreeCreate | worktree hook | clones `game/Library` (13 s) |

**Minimum path for one engine change.**
1. Create a worktree.
2. Edit.
3. Run `typecheck` (locked).
4. Run `test-domain` (16-33 min, locked).
5. Run `lint-content`.
6. Run `check.sh` (46 steps, 25-43 min including the suite).
7. Commit with an essay.
8. `land.sh`: rebase and re-gate on each lost race (up to 3 times, under the land lock), push, then verify by
   call site.
9. `wt.sh rm`, then `wt.sh sync`.

A visible change adds a 15-20 min exclusive capture and a screen-reader pass.

**The ceiling.** The best case is 45-60 minutes per landed change. Landing is serialised, so the whole studio
could land only about 1-2 changes per hour, no matter how many agents ran. Agents compensated by stacking many
commits into each land.

## 4. What their own docs already said

**`15-RESET.md` (09-04).**
- Why the slice was rejected: mechanics named after their meaning (RESERVE, VERIFY, "Too Big To Fail"); the
  world was a diagram; the story was a curriculum; and it was "not an engine" (towns as `Vector2` arrays,
  dialogue in C#).
- What it kept: the pure domain layer ("93 tests in 50 ms is the reason bugs get caught at all"), procedural
  art and audio, runtime assertions, integer money.
- Eight days later, those 93 tests in 50 ms had become 752 tests in 33 minutes.

**`08-PRODUCTION.md`.** It now carries a banner saying its market numbers are for the wrong genre. Two lines
still hold: "scope drift is the default failure and it arrives as a series of individually reasonable
additions", and the web build must be "instant".

**`32-THE-STUDIO.md` (09-13).** A local tool so the owner can write story without an agent. Its core rule is
correct: validate with the game's own loader, because "two implementations of one fact, kept in step by hand,
is the failure this project has written up twice".

**`07-TECH-ARCHITECTURE.md` §7a.** 57 shapes of "the check ran, the check passed, and the check was not
looking at the thing". They cluster into five kinds:
- gates over empty or self-excluded populations;
- tautologies, and floors printed as readings;
- measuring a different object than the one shipped (the other copy, the source instead of the carrier, the
  compositor instead of the screen);
- stale state (last run's files, a moved sha, an old build);
- reasoning errors (a corrected fact that hardens the premise; a quantifier about the search, not the world).

Almost every row traces back to copies and indirection (§2.4), or to evidence that was not the running game.

**CLAUDE.md** says "The expensive mistakes in this project have all been measurement mistakes, not coding
mistakes." That is true, and the reason is that the instruments sat too far from the game.

## 5. What the game looks and plays like now (from shots)

**Title** (web, deployed 09-15 00:13). A dark, fairly atmospheric pixel coast at night. Rows of tally marks
stand in for a title.

**Character builder.** Clean and readable: name, build, skin, hair, coat, wearing.

**The world.** Top-down at 640x360. A small figure stands on dark-green noise tiles with scattered red
flowers. A translucent fog layer sits over nearly every frame. The HUD shows only `day 1 08:00` and `0.00`.
- Contrast is low, the tile texture is busy, and landmarks are few.
- The "burning" country reads as brown static.
- The most legible frame, from 09-11, is coastal: hut, beach, sea, pinewood.

**Machines and creatures.** Machines are flat violet boxes; colour variety landed on 09-14. Creatures are
small dark sprites.

**Dialogue.** A bottom panel with parenthetical choices, e.g. "(look at the photograph again)". The writing is
terse and moody: "There is an office that will correct anything. Everybody says so."

**Systems on paper.** Real-time swing/dodge against a plate and a working part, grip/ensnare, being carried
off, hunger, wet and load, crafting, 7 arcs, Head Office.

**Evidence that it plays.** No shot shows a readable fight, and the latest tour stalled in a dialogue. The
best evidence is headless: the balance and survival sims and the text player, not frames.

**Summary.** Dense, generated, moody but murky. Many systems, weak readability, no demonstrated fun loop.

## 6. What went right (keep)

1. **Pure engine.** 29.5k lines with `noEngineReferences: true` and zero `UnityEngine` imports, so the rules
   can be tested without the renderer. 533 tests run in 6 s. On day 1 Unity became "a renderer: one scene, and
   the world is content".
2. **Content as data.** JSONC areas, actors, items and threats, plus `.usp` scripts, all validated by the
   game's own loader. By day 1 the game was "authored entirely as data, playable in a terminal".
3. **Deterministic seeds.** `Game.NewGame(db, seed)`, with SeedTests proving the seed reaches the ground.
   `frame.sh x y HH:MM seed` shows any place in about 20 s. This should have been the main loop from day 1,
   not an add-on on day 8.
4. **Headless simulation.** "Play the whole coast three ways in a millisecond." BalanceTests check that
   careful, careless and trader styles end differently.
5. **Generators as text.** Procedural art, audio and palette code merges cleanly. Only the committed PNG
   outputs caused conflicts.
6. **Owner-facing tools.** The world builder (fly over and tune the generated coast) and the story studio take
   the agent out of the owner's loop.
7. **A short ruling list at the top of CLAUDE.md that overrides the docs.** It worked better than 1,000-line
   design documents.
8. **Early web deploy with a payload budget.** Live on day 1, and the payload was cut from 15.16 MB to 8.40
   MB, measured.
9. **Worktree isolation.** Correct, but only needed because so many agents ran at once.

## 7. Rules for the new project

Each rule can be checked by a script or by reading `git log`.

1. **Latency budget.** A content, art or tuning edit is visible in the running game in ≤60 s; a code edit in
   ≤3 min. Measure weekly. If either budget is blown, fix the loop before any feature work.
2. **One copy of every fact.** No content file, constant or asset exists at two committed paths, and the game
   and tests read the same content directory. CI fails on byte-identical duplicates under `content/`.
   Generated binaries are built, never committed.
3. **Pre-land gates take ≤5 min wall clock.** Anything slower (full suite, capture, web build) runs after
   merge and never blocks landing. A post-merge red opens a fix; it does not add a gate.
4. **At least 50% of commits in any 2-day window are player-visible.** Each links a screenshot or clip taken
   at a named seed and coordinate.
5. **Tooling stays ≤30% of shipping game code.** That covers lints, probes, harnesses, hooks and dev apps, but
   not art/audio generators. A new lint must cite a bug the owner actually hit.
6. **Done means reachable.** A feature is done only when an input-driven script, starting from New Game at a
   fixed seed, reaches it in the running game. Unit tests alone never count.
7. **The owner plays a build at least every 48 h.** Verdicts go into one `RULINGS.md` of ≤150 lines. A doc
   that contradicts a ruling is fixed or deleted in the same commit.
8. **One 10-minute vertical slice first, rated fun by the owner.** Until then: no second biome, no second
   project, no engine-as-product work. The milestone list has exactly one item.
9. **At most 3 concurrent implementation agents.** Each owns disjoint directories declared at spawn. Zero
   commits land from a shared checkout.
10. **Premise changes only at milestone boundaries.** A change of genre, combat model, setting or core fantasy
    ships with a same-day deletion commit. A grep for the old premise's terms then returns nothing.
11. **Commit bodies are ≤8 lines.** Lessons live in one `LESSONS.md` of ≤100 lines. There is no
    failure-taxonomy document.
12. **Screenshot names come from runtime state** (scene, tile, open UI), not from script intent. A tour fails
    if two consecutive shots are >95% identical, or if a modal stays open for more than 3 beats.
13. **Hooks add ≤200 ms per tool call in total.** A Stop hook may only require gates that finish in ≤2 min. No
    machine-wide locks: work that needs one is too slow for the inner loop.
14. **The core engine stays pure.** Zero engine references, and the default test run takes ≤30 s. Tests slower
    than 1 s are tagged and left out of the inner loop.
15. **No source file over 1,500 lines.** CI fails on the first violation; `Game.cs` (3,643) and `AutoCapture`
    (5,688) grew into collision points unchecked.
