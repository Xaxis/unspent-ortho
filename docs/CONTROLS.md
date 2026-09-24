# Controls

How the player holds the game: three control schemes, and what a lock does to
the body. The research (2026-09-24) asked for an ideal mapping for keyboard
alone, keyboard and mouse, and keyboard and trackpad. The owner ruled on it the
same day, and this file records what shipped.

- The schemes: `src/settings/control_scheme.gd`.
- A lock's rules: `src/core/fight/lock_on.gd`.
- The scroll and trackpad gestures: `src/systems/08_pointer.gd`.
- The picker is the "how you hold the game" row on the settings page (`controls.scheme`).

## The owner's rulings

1. On a Mac, crouch is C and making is Y, so nothing sits on Ctrl.
2. Z locks in every scheme. The mouse adds middle click, and keyboard alone adds L.
3. The shoulder view is a toggle by default in all three schemes. With a mouse,
   holding the right button is a peek: the view is up while the button is held,
   then returns to wherever the key left it.
4. While the target key is held, scroll and swipe cycle the lock and zoom is off.
5. Free aim and hovering to target wait for the combat pass.
6. A lock must work in both views and turn the player to face what it holds.

## Every verb, by pressure

**Fighting.** Pressed together, fast, with the eyes on a body. The chords that
must work are **move + dodge + swing + target** and **move + cycle** while
target is held.
- move, run
- swing (also the pull that breaks a grip)
- dodge
- jump
- target (held)
- cycle the lock (next and previous)
- sweep (target held, then the scan key)
- abilities: dash, grapple (held), glide, scan (held), spoof

**Moving and sneaking.** Pressed together, with less timing pressure.
- move, run, jump
- crouch
- lamp
- ride

**Looking.** Continuous, pressed at the same time as moving.
- the shoulder view, turned and tipped up to the gaze limit
- zoom

**Taking.** Pressed one at a time.
- use
- drop

**Menus.** Calm, with the slate up. The walk keys steer every page, and use or
swing confirms.
- carrying, making, map, journal, holding, pause

**Dev.** Only while dev mode can be reached.
- toggle, note, readout, clean picture, fly, regions

## The three schemes as shipped

These rules hold in every scheme:
- Every fighting verb is reachable with the left hand on WASD.
- Shift holds to run and taps to dodge (Dark Souls' one-key roll and run), and
  dodge also has a key of its own.
- No menu key sits under a finger that fights.
- The arrows walk, and every slate page is steered by the walk. Over the
  shoulder the arrows turn the view instead, and the walk there is only the
  move keys that are not also look keys (`game.gd`).

| Verb | Mouse | Trackpad | Keyboard alone |
|---|---|---|---|
| move | WASD, arrows | WASD, arrows | WASD, arrows |
| look (shoulder view) | mouse movement, arrows | one finger on the captured pointer, arrows | arrows |
| run / tap to dodge | Shift | Shift | Shift |
| dodge | K, thumb button | K | K |
| swing / pull | J, left click | J, click | J |
| jump | Space | Space | Space |
| use | E, Enter | E, Enter | E, Enter |
| crouch | Ctrl (hold); **C (toggle) on a Mac** | C (toggle) | C (toggle) |
| target (held) | Z, middle click | Z | Z, L |
| cycle the lock | U / O, scroll | U / O, two-finger swipe | U / O |
| sweep | R while target is held | R while target is held | R while target is held |
| shoulder view (toggle) | Left Alt/Option | Option | Left Alt |
| peek (held) | right button | — | — |
| zoom | = / -, scroll | = / -, two-finger scroll, pinch | = / - |
| lamp, ride, drop | F, B, X | F, B, X | F, B, X |
| dash, scan, grapple, glide, spoof | Q, R, T, G, V | Q, R, T, G, V | Q, R, T, G, V |
| carrying | Tab, I | Tab, I | Tab (I sits over the fighting hand) |
| making | C; **Y on a Mac** | Y | Y |
| map, journal, holding, pause | M, N, H, Esc | M, N, H, Esc | M, N, H, Esc |

**Where the scroll goes.** A wheel notch, a two-finger scroll and a pinch are all
one question, and whoever holds the camera answers it, in this order:
1. a held lock cycles;
2. the shoulder view moves its eye in or out;
3. otherwise the land zooms.

On a Mac a trackpad's scroll reaches Godot as a pan gesture and a real wheel as
wheel buttons (read in the engine's `godot_content_view.mm`). That difference is
also how a mouse shows itself on a Mac that started on the trackpad scheme.

**The first-run choice.** A Mac that has shown no mouse starts on `trackpad`;
everything else starts on `mouse`. Keyboard alone is only ever chosen, never
guessed. Once a mouse wheel, middle button or side button is seen, a player who
never chose a scheme is moved to `mouse`, and that choice is kept. In a browser
a wheel does not count, because the browser sends a trackpad's scroll as a
wheel too. A shot, a tour and a test always use the PC mouse layout, so no
picture or test result depends on the laptop that made it.

**The player's own keys.** A scheme writes every key and button of every action
it names. The player's rebinds sit on top of it: a rebind replaces one action's
keyboard key, as before. Resetting a key puts back the scheme's key, not the one
in `project.godot`. Switching schemes keeps the keys the player moved. One key
per action is enough for rebinding, because the scheme carries the extra keys,
buttons and gestures. Keyboard alone needs no key combinations: about 36 verbs
fit one key each.

## Lock-on

**What comparable games do.**
- **Souls-likes** (Dark Souls, Elden Ring): the body faces the locked target. The
  camera sits behind the player on the line to the target, so forward closes and
  the sides circle. Rolls go where the stick points, and attacks go at the target.
- **Zelda's Z-targeting** (Ocarina of Time) set the pattern: holding the lock
  makes left and right a sidestep round the target.
- **Top-down action games** (Hades, Diablo) mostly have no hard lock. Aim comes
  from the cursor or an assist, and movement always reads off the screen,
  because the camera never turns.
- **Tunic**, as far as I know, combines a fixed isometric camera with a
  lock-on, and movement stays relative to the screen while the character faces
  the target.

**What we do, in both views.**
- **Facing.** The body faces what is locked. It turns onto a new lock quickly
  (`LockOn.TURN`), rather than snapping.
- **Strafing.** Motion across the line to the target is spent as arc at the
  current distance, so a strafe circles the target instead of leaving on a
  tangent (`LockOn.step`). The integration is exact, so a hundred laps end at
  the starting distance.
- **Swing.** A swing goes at the lock, and the aim assist cannot turn it onto a
  nearer body.
- **Dodge.** A dodge goes where the keys point, and the body keeps facing the
  lock. With no key held, the dodge goes straight back from the target (unlocked,
  it goes back from wherever the body faces).
- **Losing the lock.** Letting go, the target dying, or the target leaving reach
  hands the facing back as a turn onto the walk, not a snap (`LockOn.RELEASE_MS`).
- **Switching views.** The lock survives changing views in either direction.
- **Cycling.** Strafing never cycles the lock. U and O, the scroll and a swipe do.

**Over the shoulder.** The line to the target is forward: up closes, down
retreats, left and right circle. The camera aims from the shoulder the eye
stands behind, never from the head. Aimed from the head, the player's own back
stood in front of the target and hid it. Under a lock the eye stands wider
(`Shoulder.LOCK_RIGHT`), so the pair are framed together with the player left of
centre. The view is turned by however far the target's bearing moved each frame
before the ease takes the rest. Eased alone, the view trailed a body circled at
a tile and a half by more than twenty degrees. When the lock cycles to another
body, the view eases onto it instead of jumping. **The mouse and the arrows may
tip the view up or down under a lock, but they never take the turn**, so the
mouse and the lock cannot fight.

**From above.** The keys stay relative to the screen. That camera never turns to
put the target at the top of the screen. So if the keys were read relative to
the target, "up" would mean a different direction on screen depending on where
the target stood, and the picture would contradict the keys. The facing, the
arc, the swing and the dodge are the same as over the shoulder. Holding a
direction across the line to the target bends into an arc at a steady distance.
Keeping up a full circle means steering round, the way the picture shows it.

## The conflicts, and what was done

| | Found | Fix |
|---|---|---|
| C1 | On a Mac, Godot turns Ctrl+left click into a right click, press and release (`godot_content_view.mm`, `mouse_down_control`). The right button is the peek, so a crouched swing would have turned the camera. | On a Mac, crouch is C and making is Y in every scheme. `test_control_scheme` fails if any Mac scheme puts anything on Ctrl. |
| C2 | Q was both crouch and dash. | Q is only the dash. |
| C3 | While Z was held, A and D both moved the body and cycled the lock. | Cycling has actions of its own, `target_next` and `target_prev`, on U and O, the scroll and a swipe. `test_strafing_never_cycles_the_lock` goes red if the move keys come back. |
| C4 | Dev mode's letter keys R, V and G were also scan, spoof and glide. | Dev keys are the digit of their function key: 2 note, 3 readout, 4 picture, 5 fly, 6 regions. The function keys still work. No scheme uses the number row. |
| C5 | Drop, holding and the five abilities could not be rebound. | All are on the keys page, and so are the cycle and look keys. |
| C6 | The shoulder view had no keyboard look. | The arrows look over the shoulder. |
| C7 | The scroll did nothing in play. | `08_pointer` answers it. |
| C8 | Stale key text in three places: `40_fight`'s header (swing on Space), the pause and title key list (Space, Ctrl Q), and the read panel ("a d another"). | The pause list and the read panel now ask the live map for their keys, and the header is corrected. |

**Web checks, run in the real browser** (`tools/web.sh` now runs them every time):
- **Right click:** the engine prevents the canvas's context menu.
- **Tab:** the engine prevents the default on every key, so Tab never leaves the
  canvas.
- **Alt:** likewise prevented, so it can't raise a menu bar on Windows.

Measured: `{"contextmenu:2":true,"keydown:Tab":true,"keydown:Alt":true,"keyup:Alt":true}`,
with focus still on the canvas.

**Esc and pointer lock was a real bug.** Every browser releases a pointer lock
on Esc, and the engine has no listener for that release, so over the shoulder
the first Esc paused nothing. Now, once the lock has been seen held, a pointer
the browser hands back opens the pause page (`41_shoulder`,
`_given_back_by_the_browser`). Only on the web: a desktop window keeps its
capture through Esc.

## What proves it

- **Tests:** `tests/fight/test_lock_on.gd`, `tests/settings/test_control_scheme.gd`,
  `tests/settings/test_pointer.gd`, and new cases in
  `tests/target/test_target_system.gd` and `tests/camera/test_shoulder.gd`. Each
  new rule was checked by putting the old behaviour back and watching its test go
  red.
- **Tours:** `tours/lockon_top.tour` and `tours/lockon_shoulder.tour`. Each locks
  a machine, circles it, dodges, swings, cycles to another, switches views with
  the lock held and lets go. Every frame claims what it shows (`lock_facing`,
  `lock_circled`, `shoulder_locked`, `target:KIND`), and the claim is checked
  again when the shutter falls.
