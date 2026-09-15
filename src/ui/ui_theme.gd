class_name UiTheme
## The notebook's colours and the Godot Theme built from them. The player's UI
## is a hand-ruled notebook: linen paper, ink, and ONE accent (a rust-red ink,
## the colour of the margin line). Nothing else on a page is saturated.

const PAPER := Color("#e8dcc0") # linen 5
const PAPER_SHADE := Color("#c0b394") # linen 4
const PAPER_DEEP := Color("#968a76") # linen 3
const PAPER_EDGE := Color("#6f6559") # linen 2
const INK := Color("#12111d") # ink 1: text on paper
const INK_DEEP := Color("#08070f") # ink 0: outlines, never pure black
const INK_SOFT := Color("#2f2c45") # ink 3: second-level text
## Rows that cannot be chosen now: still selectable, confirming says why.
const FADED := Color("#6c6555")
## The one accent: cursor, margin, a wound, a shortfall.
const ACCENT := Color("#9a4f28") # rust 3
const ACCENT_BRIGHT := Color("#c47438") # rust 4, for the HUD over the world
## Printed forms pasted into the notebook: a whiter, harder stock.
const SLIP := Color("#efe8d6")
## Blue-grey of the printed rules on the paper.
const RULE := Color("#b9b8a8")
## Covers and cloth behind the pages.
const COVER := Color("#33231f") # earth 1
const COVER_LIGHT := Color("#4f3627") # earth 2
## HUD text over the world: paper-coloured with an ink rim, readable on snow and sea.
const HUD_TEXT := Color("#e8dcc0")
const HUD_DIM := Color("#c0b394")
## Dims the world behind an open notebook.
const VEIL := Color(0.031, 0.027, 0.059, 0.62)

## Line pitch of ruled paper and of every list: one text line plus a clear row.
const LINE := 11

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = UiFont.font()
	t.default_font_size = UiFont.SIZE
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "Label", 1)
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = INK_DEEP
	paper.set_border_width_all(1)
	paper.anti_aliasing = false
	paper.set_content_margin_all(6)
	t.set_stylebox("panel", "Panel", paper)
	t.set_stylebox("panel", "PanelContainer", paper)
	for kind: String in ["Button", "LineEdit"]:
		t.set_font("font", kind, UiFont.font())
		t.set_font_size("font_size", kind, UiFont.SIZE)
		t.set_color("font_color", kind, INK)
		t.set_stylebox("normal", kind, paper)
		var focus := paper.duplicate() as StyleBoxFlat
		focus.border_color = ACCENT
		t.set_stylebox("focus", kind, focus)
		t.set_stylebox("hover", kind, paper)
		t.set_stylebox("pressed", kind, focus)
	_theme = t
	return t
