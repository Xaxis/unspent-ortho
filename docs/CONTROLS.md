# Controls: three schemes

Research for the owner (2026-09-24): an ideal mapping of every player control in
three schemes: keyboard only, keyboard and mouse, and keyboard and a trackpad.
Nothing here is built yet. Section 4 says how it would ship.

The map today is `[input]` in `project.godot`, plus mouse buttons added at
runtime by `src/settings/mouse_controls.gd`, plus dev keys added by
`src/dev/dev_mode.gd`. Everything below was read off those files and the
systems that read them, not off `docs/DESIGN.md`'s key line, which is behind
(it has no abilities, no shoulder view, no zoom).

## 1. Every verb, by pressure

**Fighting.** These are pressed together, fast, with the eyes on a body.
- move (4 directions), run (held)
- swing, which is also the pull that breaks a grip
- dodge (i-frames)
- jump: up 2 levels, across 2 tiles, no swing or dodge in the air
- target: held, locks the nearest threat and leans the camera
- cycle the lock (next and previous), which also pages a sweep
- sweep: while the target key is held, read the whole field
- abilities: dash, grapple (held), glide, scan (held), spoof

The chords that must work: **move + dodge + swing + target**, and
**move + cycle** while target is held. Every dodge and swing lands with a
direction key already down.

**Moving and sneaking.** Pressed together, with less timing pressure.
- move, run, jump
- crouch (hold or toggle)
- lamp (lighting it gives you away)
- ride: board, launch, leave or strip a craft

**Looking.** Continuous, pressed at the same time as moving.
- shoulder view (hold or toggle), then turn it and tip it up to about 45° (the
  gaze at the colossi)
- zoom in and out: the height of the view from above, or the eye's distance in
  the shoulder view

**Taking.** Pressed one at a time, at a place.
- use: take, read, talk, open a cache, enter a shaft
- drop

**Making and menus.** Calm, with the slate up. The move keys navigate it and
use or swing confirm.
- carrying, making, map, journal, holding, pause and back
- settings are reached from pause

**Dev.** Only while dev mode can be reached.
- toggle, note, readout, clean picture, fly, fly in and out, regions

## 2. The three schemes

Rules held in all three:
- **Left hand on WASD.** Every fighting verb is reachable without lifting it.
- **Run and dodge share Shift**: hold to run, tap to dodge. This is DodgeInput's
  rule today and Dark Souls' before it. Dodge also gets a key of its own, so
  nobody has to tap.
- **A menu key is never under a finger that fights.** A slip mid-fight must
  not open a page over the world.
- **Only one thing changes by context, and it is the scroll.** While target is
  held, scroll cycles the lock; otherwise it zooms. That frees A and D to
  strafe while locked (conflict C3 below).

### 2a. Keyboard and mouse (the default on a desktop)

| Verb | Keys and buttons | Default | Why there |
|---|---|---|---|
| move | W A S D (arrow keys too) | — | standard; relative to the camera, as today |
| run / dodge | Shift | hold runs, tap dodges | Dark Souls' one-key roll and run |
| dodge | mouse thumb (back) button, K | press | the dodge lands with the swing without crossing hands |
| swing / pull | left click (J too) | press | the verb the hand expects |
| jump | Space | press | universal |
| shoulder view | right button, Left Alt/Option | **hold** | held right mouse for an over-shoulder view is the third-person norm; the pointer is captured while the view is up |
| look (shoulder view) | mouse movement | — | turns the view and tips it up to the gaze limit |
| target | Z, middle click | hold | Z is where players already have it; middle click is Dark Souls III's lock-on |
| cycle lock | scroll while target is held (A/D no longer cycle) | — | A/D stay free to strafe round the body |
| sweep | R while target is held | — | as today: the scan key reads the field |
| zoom | scroll (when not targeting), = and - | — | scroll zoom is what every top-down game does |
| use | E (Enter too) | press | universal "interact" |
| crouch | Ctrl on Windows and Linux; C on macOS (see C1) | hold on Win/Linux, **toggle on Mac** | Ctrl is the PC norm |
| lamp | F | press | "flashlight" in most PC games |
| ride | B | press | unchanged |
| drop | X | press | unchanged |
| dash | Q | press | the mobility key beside the move keys, as in Hades; crouch is taken off Q (C2) |
| scan | R | hold | unchanged, and doubles as the sweep |
| grapple | T | hold | unchanged |
| glide | G | press | unchanged |
| spoof | V | press | unchanged |
| carrying | Tab, I | — | Tab is the survival-game norm (Valheim, Rust) |
| making | C (Win/Linux); Y on Mac (see C1) | — | |
| map | M | — | universal |
| journal | N | — | unchanged |
| holding | H | — | unchanged |
| pause / back | Esc | — | universal |

No free aim and no hovering to target. `mouse_controls.gd` defers both as a
combat pass of their own, and this doc does not change that.

### 2b. Keyboard and trackpad (a Mac laptop, no mouse)

A trackpad has **no right-drag, no middle button and no thumb button**. The
secondary click (two fingers, or a corner) is a click and cannot be held
comfortably while moving the pointer. macOS turns Ctrl+click into a right
click. And two-finger scrolling reaches Godot on macOS as a **pan gesture, not
a wheel** (a wheel on the web), with pinch as a magnify gesture.

| Verb | Keys and gestures | Default | Why |
|---|---|---|---|
| move, run/dodge, jump, use, lamp, ride, drop, abilities, menus | as 2a, Mac column | — | the keyboard half is the same |
| swing / pull | click (J too) | press | a physical click; see the note on tap-to-click below |
| dodge | Shift tap, K | press | no thumb button |
| shoulder view | Option (Left Alt) | **toggle** | nothing can be held on the pad while the pointer moves; a toggle frees the hand |
| look (shoulder view) | one finger moving the captured pointer | — | the pointer is held while the view is up, so no button needs holding |
| zoom | two-finger scroll up/down; pinch | — | the macOS convention |
| target | Z | hold | |
| cycle lock | two-finger swipe left/right while target is held; also [ and ] | — | A/D stay free to move |
| crouch | C | **toggle** | never Ctrl: see C1 |
| making | Y | — | C is taken by crouch |

Tap-to-click (a macOS setting) turns a resting finger into a swing. The settings
page should say so and recommend a physical click for this scheme. The game
cannot read the OS setting.

### 2c. Keyboard only

This is the left-hand-moves, right-hand-fights layout that keyboard-only action
games settle on (Hollow Knight puts the verbs on Z/X/C beside the arrow keys);
today's J/K already lean this way. The right hand rests on J K L.

| Verb | Keys | Default | Why |
|---|---|---|---|
| move | W A S D | — | |
| run / dodge | Shift | hold runs, tap dodges | |
| jump | Space | press | left thumb |
| swing / pull | J | press | right index finger at home |
| dodge | K | press | right middle finger, pressed with J without moving the hand |
| target | L | **hold** | moved from Z: holding Z with the left ring finger while it also moves is the finger clash in C3 |
| cycle lock | U (previous), O (next) | — | directly above J/L, so the right hand cycles while the left keeps moving |
| sweep | R while L is held | — | |
| shoulder view | Left Alt/Option | **toggle** | left thumb |
| look (shoulder view) | arrow keys, only while the view is up (they move the player otherwise, as today) | — | the one keyboard look there can be; the view already eases in behind the player when look is left alone, so exploring needs little of it |
| zoom | = and - | — | |
| use | E, Enter | press | |
| crouch | C | **toggle** | holding a pinky key while also running is the thing keyboard-only players complain about |
| lamp F, ride B, drop X, abilities Q R T G V | as 2a | | all under the left hand |
| carrying | Tab (not I: I sits above the fighting hand, where a slip opens it mid-fight) | — | |
| making | Y | — | |
| map M, journal N, holding H, pause Esc | | | |

**No chords are needed.** There are about 36 verbs and the board holds them one
key each. The only doubled key is Shift, and that is timing (tap or hold), not
a chord.

## 3. Conflicts in today's map, and the fix

- **C1. Ctrl+click is a right click on macOS, and right click is the shoulder
  view.** Crouching and swinging (the stealth attack) flips the camera. Fix: on
  macOS and in the trackpad scheme, crouch moves off Ctrl to C, with toggle as
  the default, and making moves from C to Y. Windows and Linux keep Ctrl.
  Confirm first with a one-line probe that Godot 4.7 does this translation (it
  has done it on macOS in past versions); if it does not, only the trackpad
  scheme needs the move.
- **C2. Q is both crouch and dash.** Once a dash is fitted, every crouch on Q
  is also a dash. Fix: take Q off crouch in all schemes.
- **C3. While Z is held, A and D both move the body and cycle the lock**
  (`42_target.gd` reads `move_left`/`move_right` edges). Every strafe while
  locked changes the target, and the left hand is holding Z and pressing A at
  once. Fix: give cycling actions of its own (`target_next`, `target_prev`) on
  scroll, a two-finger swipe, or U/O, and stop reading the move keys.
- **C4. Dev letters collide with abilities.** `dev_mode.gd`'s header says its
  letters are ones "the game does not already own", which was true before the
  abilities got keys. Today R is readout and scan (and the sweep), V is fly and
  spoof, and G is regions and glide, all live together in any session where dev
  mode can be reached. Fix: dev letters work only while the backtick is held
  (backtick+R and so on), or only while the dev app is open. The function-row
  keys stay as they are.
- **C5. Not bindable today:** `drop`, `holding`, all five `ability_*` and the
  new cycle actions are missing from `PlayerSettings.BINDABLE`, so a player
  cannot move them.
- **C6. The shoulder view has no keyboard look.** It turns only with the mouse,
  so keyboard only has no way to gaze. Fix: arrow-key look while the view is up
  (2c).
- **C7. Scroll does nothing in play.** Only the dev flyover reads the wheel, and
  no pan or magnify gesture is read anywhere. Zoom is keys only.
- **C8. Stale comment.** `40_fight.gd`'s header says swing is on Space; Space
  is jump.
- **Web: check before shipping.** Esc also releases the browser's pointer lock,
  so the first Esc in the shoulder view may never reach pause. Left Alt can put
  focus on the browser's menu bar on Windows. Right click must not open the
  context menu. Tab must not move focus off the canvas. All four want one
  `tools/web.sh` tour.

## 4. How to ship it

- **A scheme is a preset over the whole input map, not a set of `bind_key`
  calls.** `bind_key` puts exactly one key on an action and leaves the mouse
  buttons alone. A preset needs several events per action (dodge is Shift, K
  and a thumb button), mouse buttons, and gestures. So: one CHOICE row,
  `controls.scheme` (`mouse`, `trackpad`, `keys`), whose preset writes every
  event of every action it names, including the ones `MouseControls.ALSO`
  hard-codes today. The player's own rebinds are then applied on top as
  overrides, and "reset" returns to the preset, not to `project.godot`.
- **The preset also sets the hold-or-toggle defaults** (`playing.crouch`,
  `playing.shoulder`, `playing.target`), unless the player has chosen one
  explicitly.
- **The default preset is chosen once**: `trackpad` on macOS when no mouse has
  been seen (a mouse is hard to detect reliably before one moves, so this is
  the first-run default, not a live switch), otherwise `mouse`. The web asks
  the same question of the browser.
- **One key per action is enough for the player's own rebinding.** Presets
  carry the extra events, and a rebind replaces only the keyboard key, as it
  does now. Keyboard only needs no chords (see 2c).
- **New code the presets need:** the `target_next` and `target_prev` actions;
  scroll, pan and magnify read in `41_shoulder`/`09_view` and in `42_target`
  (which takes the scroll while it is held); arrow-key look in `41_shoulder`;
  and the missing rows in BINDABLE (C5). The settings page's keys list already
  reads the live `InputMap`, so it shows whatever the preset put there.

**Borrowed from:** Dark Souls and Elden Ring (one key taps to roll and holds to
run; lock-on, switched without leaving the move keys); Hades (WASD relative to
the screen, left click to attack, the dash beside the move keys); Valheim and
Rust (Tab for carrying, Ctrl crouch, E use); the held right button over the
shoulder of most third-person PC games; Hollow Knight and keyboard brawlers
(one hand moves, the other fights); and the macOS trackpad conventions
(two-finger scroll and pinch zoom, the secondary click as a click only).

## Open questions for the owner

1. Crouch on C and making on Y on the Mac: is that acceptable, or would you
   rather keep crouch on Ctrl everywhere and only force toggle on the Mac?
2. In keyboard only, target moves from Z to L. Keep Z as a second key for
   players who learnt it?
3. Should the shoulder view be a toggle by default on the trackpad and
   keyboard-only schemes, as proposed, or held everywhere?
4. Scroll cycles the lock while target is held. Is it acceptable that zoom is
   unavailable while locked?
5. Free aim (the body faces the pointer) and hovering to target are held for
   the combat pass. Should the mouse scheme wait for them before it ships?
