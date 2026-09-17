class_name UiBase
extends RefCounted
## The one place that says how big a screen is (docs/LOOK.md).
##
## Two sizes, and the difference between them is the whole of this file:
##
##   SIZE    1920x1080 — the engine's base. The frame a shot captures, the space
##           the 3D world is drawn in, what `viewport_width/height` say.
##   DESIGN  640x360 — the space the SLATE is drawn in. Every number in `src/ui/`
##           (a margin, a device rect, a gauge, the pixel font's glyphs) is in
##           these units, because the slate was drawn for them.
##
## LANTERN raised the first and deliberately did NOT redraw the second. A layer of
## UI is drawn in DESIGN units and scaled by `SCALE` onto the base, so the slate,
## the HUD and the title lay out exactly as they did at 640x360 — same margins,
## same anchors, same whole pixels — three times the size. Nothing moved, so
## nothing is anchored into empty space, and the pictures can be compared.
##
## This is a FLOOR, not the finished answer. The slate is to be redrawn
## resolution-independently (docs/LOOK.md §2); when an app is, it stops scaling
## itself and draws in SIZE units directly. That is why `fit()` is called per
## layer and not once globally: they can be converted one at a time.
##
## Why a layer transform and not `content_scale_size`: the root viewport's content
## scale is what the 3D is rendered at, and pinning it to 640x360 would have pinned
## the world's resolution too — which is the one thing LANTERN exists to undo.

## The engine's base: what a frame is, and what a shot captures.
const SIZE := Vector2i(1920, 1080)

## The space the slate is drawn in. Every literal in `src/ui/` is in these units.
const DESIGN := Vector2i(640, 360)

## Whole pixels of the base to one of the slate's. 1920/640 = 1080/360 = 3, and
## it is a whole number on purpose: the pixel font and every 1px rule stay sharp.
const SCALE := 3


## Draw this layer's contents in DESIGN units, scaled onto the base.
##
## Called by whoever makes a UI CanvasLayer. A layer that has been redrawn for the
## full base simply stops calling it.
static func fit(layer: CanvasLayer) -> void:
	if layer == null:
		return
	layer.transform = Transform2D().scaled(Vector2(SCALE, SCALE))


## The DESIGN-space rectangle of the whole screen: what a full-screen veil, band
## or fade covers. The sites that used to write `Rect2i(0, 0, 640, 360)` ask here.
static func screen() -> Rect2i:
	return Rect2i(Vector2i.ZERO, DESIGN)


## The horizontal middle of the slate, in DESIGN units. Anything centred on the
## glass (a message line, a place name, the hint) measures from here rather than
## from a 320 nobody could search for.
static func mid_x() -> int:
	return DESIGN.x / 2


## A point in VIEWPORT pixels brought into DESIGN units.
##
## This is the trap the base change laid, and it is worth stating plainly because
## it is silent: `Camera3D.unproject_position` answers in the viewport's own
## pixels, which are now 1920x1080, while anything drawn on a `fit()` layer is in
## the slate's 640x360 units. Mixing them put every machine's tag three times too
## far down and to the right — off the glass entirely, so the tags simply stopped
## being drawn and two targeting tests went red with "0 marks".
##
## So: anything that turns a WORLD position into a place to DRAW on a fitted layer
## goes through here. Anything that compares one unprojected point with another
## (the audio pan, which measures against the viewport's own centre) must NOT —
## both sides are already in the same space.
static func to_design(p: Vector2) -> Vector2:
	return p / float(SCALE)
