class_name UiBase
extends RefCounted
## The one place that says how big a screen is (docs/LOOK.md).
##
## LANTERN's floor raised the engine's base to 1920x1080 and left the slate drawn
## at 640x360, scaled onto it three times over. This file is where that was
## undone: **the slate is now drawn in the base's own pixels**, and the ratios
## that used to be one number are two, because they are two different decisions.
##
##   SIZE     1920x1080 — the engine's base. The frame a shot captures, the space
##            the 3D world is drawn in, what `viewport_width/height` say, and the
##            units every number in `src/ui/` is now written in.
##   PITCH    2 — base pixels to one pixel of the stolen module's glass. A rule,
##            a pip, a dead pixel and a glyph's cell are all one module pixel, so
##            the slate is still a pixel device; it is a device with a finer
##            screen than it had. It is a WHOLE number on purpose.
##   TYPE     2 — base pixels to one pixel of the hand-cut face (`UiFont`). Equal
##            to PITCH, so type sits on the module's own grid.
##   FURNITURE 3 — what the device, its bezel, its panes and its margins were
##            multiplied by when they came across from the old 640x360 space.
##
## FURNITURE (3) is bigger than TYPE (2) and that difference is the whole change:
## the device covers the same share of the frame it always did, while the words
## on it are two-thirds the size they were, so **half again as much fits on the
## glass** and the interface stops shouting over a world that is now lit and
## sharp. Neither number appears outside this file's own comments — a pane's size
## is written out in base pixels where it is declared.
##
## ## The legacy space, and why it survives
##
## DESIGN/SCALE/fit/to_design are the OLD 640x360 slate space. Exactly three
## things still draw in it, and each has a reason:
##
##   the loading page   `src/boot/boot_page.gd` is drawn a second time, by hand,
##                      in `src/boot/shell.html`, so the browser has the same
##                      device on screen while the engine downloads. The two are
##                      held equal by `tests/export/test_export.gd`. Moving one
##                      without the other is a visible jump at the hand-over, and
##                      the loading page is not what LANTERN is about.
##   the gallery        `src/gallery.gd`: a tool scene, never shipped.
##   lightning          `src/render/weather/` — frozen to the `lit` wave.
##
## They keep `fit()`, `to_design()` and `UiFont`'s legacy face, and nothing about
## them changed. A converted layer sets no transform at all and writes base
## pixels; that is the whole of the conversion.

## The engine's base: what a frame is, and what a shot captures. Everything in
## `src/ui/` and `src/dev/` is measured in these.
const SIZE := Vector2i(1920, 1080)

## Base pixels to one pixel of the stolen module's glass: a dead pixel, a grain
## of dirt, a dot of a dotted rule. Whole on purpose, and the number `UiFont`
## cuts its cell to. A RULE is finer than this — one base pixel — because a
## hairline under 14-pixel type is the hierarchy, and because 3-pixel slabs are
## half of what made the old slate shout.
const PITCH := 2

## The old slate space, for the three legacy drawers named above.
const DESIGN := Vector2i(640, 360)
const SCALE := 3


## Draw this LEGACY layer's contents in DESIGN units, scaled onto the base.
##
## Only the loading page, the gallery and the bolt layer still call this. A layer
## drawn in base pixels — every app, the HUD, every mark over the world — sets no
## transform, and passing one here would scale it three times over.
static func fit(layer: CanvasLayer) -> void:
	if layer == null:
		return
	layer.transform = Transform2D().scaled(Vector2(SCALE, SCALE))


## The whole screen in BASE pixels: what a full-screen veil, band or fade covers.
static func screen() -> Rect2i:
	return Rect2i(Vector2i.ZERO, SIZE)


## The horizontal middle of the screen, in base pixels. Anything centred on the
## glass (a message line, a place name, the hint) measures from here rather than
## from a number nobody could search for.
static func mid_x() -> int:
	return SIZE.x / 2


## The same rectangle in the LEGACY space, for the loading page and the gallery.
static func legacy_screen() -> Rect2i:
	return Rect2i(Vector2i.ZERO, DESIGN)


## A point in VIEWPORT pixels brought into LEGACY DESIGN units.
##
## `Camera3D.unproject_position` answers in the viewport's own pixels, which are
## the base's. A layer drawn in base pixels therefore needs NO conversion at all
## and must not call this: a world position is already where it should be drawn.
## A layer still on `fit()` does, and that is all this is now for.
##
## The trap it was written for is worth keeping on the record because it was
## silent: mixing the two spaces put every machine's tag three times too far down
## and to the right — off the glass entirely, so the tags simply stopped being
## drawn and two targeting tests went red with "0 marks".
static func to_design(p: Vector2) -> Vector2:
	return p / float(SCALE)
