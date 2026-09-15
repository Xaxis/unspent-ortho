class_name UiTheme
## The slate's colours (docs/ART.md §9) and the Godot Theme built from them.
##
## The slate is a display module stolen from a machine in a patched bezel. Its
## glass is near-black, never black. Everything the player's own slate says is
## ONE phosphor, a cold green (amber would compete with the machines' working
## parts, the brightest warm pixels in a frame). One warning colour, used only
## for what needs acting on. What the stolen module reads off the machines
## (scans, interference, found tech) is shown in the module's own violet.

## The glass, dark to lit.
const GLASS_OFF := Color("#060a0c") # asleep: the powered-down glass, never pure black
const GLASS := Color("#0b1315")
## Every other row of the glass is a hair lighter: the module's scan structure.
const GLASS_ROW := Color("#0d1618")
## The bar under a chosen row.
const GLASS_LIT := Color("#12211f")
## The replacement sub-panel: a module from another device, bluer and a step lighter.
const GLASS_SPARE := Color("#0e151b")
const GLASS_SPARE_ROW := Color("#10181e")

## The phosphor ramp, dark to bright. Text is 3; secondary 2; rules, sockets
## and glyph outlines 1; burn-in ghosts 0; the chosen row and a hot readout 4.
## No word is ever dimmer than TEXT_DIM (or MACHINE[2] in violet): both keep
## 4.5:1 on the glass and 3:1 at the low-power floor. FAINT, GHOST and
## MACHINE[0..1] are never used for words.
const PHOSPHOR: Array[Color] = [Color("#173029"), Color("#2b5c4c"), Color("#4f9b81"), Color("#87d9b5"), Color("#c9fbe2")]
const TEXT := Color("#87d9b5")
const TEXT_DIM := Color("#4f9b81")
const FAINT := Color("#2b5c4c")
const GHOST := Color("#173029")
const BRIGHT := Color("#c9fbe2")

## The one warning: a wound, a shortfall, a refusal, the last cell.
const WARN := Color("#ff6f4f")
const WARN_DIM := Color("#8e3b2c")

## The stolen module's violet, dark to bright: machine-sourced data only.
const MACHINE: Array[Color] = [Color("#241f38"), Color("#4b4274"), Color("#8579c0"), Color("#b3a8ea"), Color("#e0dbff")]

## Over the world (HUD): readouts are phosphor held by a rim of dead glass.
const RIM := Color("#050809")
## Dims the world behind the awake slate.
const VEIL := Color(0.02, 0.03, 0.035, 0.66)

## Line pitch of every list: one text line plus a clear row.
const LINE := 11

static var _theme: Theme


## Every colour the slate draws its screens with (tests hold these to the rules).
static func all_colours() -> Array[Color]:
	var out: Array[Color] = [GLASS_OFF, GLASS, GLASS_ROW, GLASS_LIT, GLASS_SPARE, GLASS_SPARE_ROW, TEXT, TEXT_DIM, FAINT, GHOST, BRIGHT, WARN, WARN_DIM, RIM]
	out.append_array(PHOSPHOR)
	out.append_array(MACHINE)
	return out


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = UiFont.font()
	t.default_font_size = UiFont.SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "Label", 1)
	var glass := StyleBoxFlat.new()
	glass.bg_color = GLASS
	glass.border_color = FAINT
	glass.set_border_width_all(1)
	glass.anti_aliasing = false
	glass.set_content_margin_all(6)
	t.set_stylebox("panel", "Panel", glass)
	t.set_stylebox("panel", "PanelContainer", glass)
	for kind: String in ["Button", "LineEdit"]:
		t.set_font("font", kind, UiFont.font())
		t.set_font_size("font_size", kind, UiFont.SIZE)
		t.set_color("font_color", kind, TEXT)
		t.set_stylebox("normal", kind, glass)
		var focus := glass.duplicate() as StyleBoxFlat
		focus.border_color = BRIGHT
		t.set_stylebox("focus", kind, focus)
		t.set_stylebox("hover", kind, glass)
		t.set_stylebox("pressed", kind, focus)
	_theme = t
	return t
