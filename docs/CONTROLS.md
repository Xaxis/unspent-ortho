# Controls

Contract for the built control schemes and what a lock does to the body.

- The schemes: `src/settings/control_scheme.gd`; the picker is the "how you hold the game"
  row on the settings page (`controls.scheme`).
- A lock's rules: `src/core/fight/lock_on.gd`.
- The scroll and trackpad gestures: `src/systems/08_pointer.gd`.

## The owner's rulings

1. On a Mac, crouch is C and making is Y, so nothing sits on Ctrl.
2. Z locks in every scheme. The mouse adds middle click, and keyboard alone adds L.
3. The shoulder view is a toggle by default in all three schemes. With a mouse,
   holding the right button is a peek: the view is up while the button is held,
   then returns to wherever the key left it.
4. While the target key is held, scroll and swipe cycle the lock and zoom is off.
5. Free aim and hovering to target wait for the combat pass.
6. A lock must work in both views and turn the player to face what it holds.

## The three schemes

Rules in every scheme:
- Every fighting verb is reachable with the left hand on WASD. The chords that must work
  are **move + dodge + swing + target** and **move + cycle** while target is held.
- Shift holds to run and taps to dodge; dodge also has a key of its own.
- No menu key sits under a finger that fights. No scheme uses the number row.
- The arrows walk, and every slate page is steered by the walk (use or swing confirms).
  Over the shoulder the arrows turn the view instead, and the walk there is only the move
  keys that are not also look keys (`game.gd`).
- On a Mac nothing sits on Ctrl: Godot turns Ctrl+left click into a right click, which is
  the peek (`test_control_scheme` fails on it).
- Cycling has actions of its own (`target_next`, `target_prev`); strafing never cycles
  (`test_strafing_never_cycles_the_lock`).
- Dev keys are the digit of their function key: 2 note, 3 readout, 4 picture, 5 fly,
  6 regions (the function keys still work).
- Every action is on the keys page, including drop, holding, the abilities, cycle and look.

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

**Where the scroll goes.** A wheel notch, a two-finger scroll and a pinch are one question,
answered in this order: a held lock cycles; else the shoulder view moves its eye in or out;
else the land zooms. On a Mac a trackpad's scroll arrives as a pan gesture and a wheel as
wheel buttons, which is also how a mouse shows itself.

**The first-run choice.** A Mac with no mouse seen starts on `trackpad`, everything else on
`mouse`; keyboard alone is only chosen. A player who never chose moves to `mouse` on the
first wheel, middle or side button (in a browser a wheel does not count). Shots, tours and
tests always use the PC mouse layout.

**The player's own keys.** A scheme writes every key and button of every action it names;
a rebind replaces one action's keyboard key on top. Resetting puts back the scheme's key,
not `project.godot`'s. Switching schemes keeps the keys the player moved. Every key shown
is asked of the live map.

## Lock-on

In both views:
- **Facing.** The body faces what is locked, turning onto a new lock quickly (`LockOn.TURN`),
  never snapping.
- **Strafing.** Motion across the line to the target is spent as arc at the current distance
  (`LockOn.step`), exactly: a hundred laps end at the starting distance.
- **Swing** goes at the lock; the aim assist cannot turn it onto a nearer body.
- **Dodge** goes where the keys point, the body still facing the lock. With no key held it
  goes straight back from the target (unlocked, back from the facing).
- **Losing the lock** (let go, target dead or out of reach) hands the facing back as a turn
  onto the walk (`LockOn.RELEASE_MS`). The lock survives switching views.
- **Only what is seen is locked fresh.** A machine or person is picked or cycled onto only
  when the line from the player's head passes through nothing drawn and under no ground
  (`Shoulder.sees`, against the footprints the shoulder camera is kept out of): locking
  through a wall is a free scan in a game about not being seen. A held lock keeps its grace
  behind cover. Places are read by what shows of them over everything else. A sweep is held
  to the same rule: it reads what is seen, plus any body that has come for the player
  (alerted, chasing, striking), which would be heard.

**Over the shoulder.** Up closes, down retreats, left and right circle. The camera aims from
the shoulder the eye stands behind, never the head (the back hid the target), wider under a
lock (`Shoulder.LOCK_RIGHT`). The view turns by the target's bearing change each frame
before easing, so a circled body is never trailed; a cycle eases onto the new body. A
villager on the line is looked over (`Shoulder.CLEAR_TIP`). **The mouse and the arrows may
tip the view up or down under a lock, but they never take the turn**, so the mouse and the
lock cannot fight.

**From above.** The keys stay relative to the screen, because that camera never turns; keys
relative to the target would contradict the picture. A full circle means steering round.

## The web

`tools/web.sh` checks every run in the real browser: the canvas's context menu is prevented,
Tab never leaves the canvas, Alt raises no menu bar. Every browser releases pointer lock on
Esc and the engine does not hear it, so once the lock has been seen held, a pointer the
browser hands back opens the pause page (`41_shoulder`, `_given_back_by_the_browser`). Web
only: a desktop window keeps its capture through Esc.

## What proves it

Tests `test_lock_on`, `test_control_scheme`, `test_pointer`, `test_target_system`,
`test_shoulder`; tours `lockon_top`, `lockon_shoulder`, `lockon_crowd` (recipes in the verify
skill, machines-fight.md and world-look.md).
