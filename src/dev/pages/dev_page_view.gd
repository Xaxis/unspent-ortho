class_name DevPageView
extends DevPage
## What is seen: the camera's zoom, the readout on the glass's edge, the slate's
## edge hidden, a clean picture, and leaving for the title.

const ZOOMS: Array[float] = [8.0, 11.0, 15.0, 20.0, 26.0, 34.0, 46.0]


## What the quality row reads: what the player chose, and what that came out as
## when it was `auto`, because "auto" alone does not say what is being drawn.
func _quality_now() -> String:
	var chose := StringName(str(PlayerSettings.value(&"picture.quality")))
	var now := Quality.current_id()
	return String(now) if chose == now else "%s (%s)" % [chose, now]


func heading() -> String:
	return "VIEW"


func rows() -> Array[Dictionary]:
	return [
		item(&"zoom", "zoom", str(snappedf(game.camera.view_height, 0.1)), {"steps": true}),
		item(&"readout", "readout on the edge", "yes" if DevMode.readout else "no", {"steps": true}),
		item(&"hud", "slate's edge", "hidden" if DevSession.hud_hidden else "shown", {"steps": true}),
		item(&"quality", "quality", _quality_now(), {"steps": true}),
		item(&"fly", "fly over the island", "flying" if _flying() else "on the ground"),
		item(&"picture", "a picture, nothing of the slate"),
		header(""),
		item(&"title", "to the title", "", {"tone": "warn"}),
	]


## The flyover, found by what it KEEPS rather than by its number.
func _flyover() -> Object:
	if game == null:
		return null
	for sys in game.systems:
		if sys.has_method(&"where") and sys.get("flying") != null:
			return sys
	return null


func _flying() -> bool:
	var f := _flyover()
	return f != null and bool(f.get("flying"))


func confirm(row: Dictionary) -> void:
	match row.id:
		&"fly":
			var f := _flyover()
			if f == null:
				refuse("no flyover in this game")
				return
			f.call(&"_toggle")
			screen.close()
		&"picture":
			var dev := DevCheats.system(game, "94_dev")
			if dev != null:
				dev.call("picture_soon")
			screen.close()
		&"title":
			if screen.ask("title", "Again: this game is left without a save."):
				screen.close()
				UiTitle.replace_game.call_deferred(game)
		_:
			side(row, 1)


func side(row: Dictionary, dir: int) -> void:
	match row.id:
		&"zoom":
			var at := 0
			var best := INF
			for i in ZOOMS.size():
				if absf(ZOOMS[i] - game.camera.view_height) < best:
					best = absf(ZOOMS[i] - game.camera.view_height)
					at = i
			game.camera.view_height = ZOOMS[clampi(at + dir, 0, ZOOMS.size() - 1)]
		&"readout":
			DevMode.set_readout(not DevMode.readout)
		&"hud":
			DevSession.hud_hidden = not DevSession.hud_hidden
		&"quality":
			# Through the player's own door, so what dev mode changes here is what
			# a player would have changed, and it is applied the same way.
			PlayerSettings.step(&"picture.quality", dir)
		_:
			return
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 16
	match screen.menu.selected().get("id", &""):
		&"zoom":
			y = panel_heading(ci, r, y, "zoom")
			panel_wrapped(ci, r, y, "How much of the world stands in the frame, in tiles tall. The game is played at 15.")
		&"readout":
			y = panel_heading(ci, r, y, "readout", true)
			panel_wrapped(ci, r, y, "Where the player is, the sky, the bodies about and what a frame costs, on the glass's edge while playing. F3.")
		&"hud":
			y = panel_heading(ci, r, y, "slate's edge")
			panel_wrapped(ci, r, y, "The health, the clock and every readout clipped to the corners, gone until shown again.")
		&"quality":
			y = panel_heading(ci, r, y, "quality")
			var q := Quality.current()
			var px := Quality.render_pixels()
			panel_wrapped(ci, r, y, "How much of the picture this machine is asked to draw. %s: %s The world is rendered at %d x %d and the slate always at %d x %d." % [
				str(q.get("label", "?")), str(q.get("note", "")), px.x, px.y, UiBase.SIZE.x, UiBase.SIZE.y])
		&"fly":
			y = panel_heading(ci, r, y, "fly over the island")
			y = panel_wrapped(ci, r, y, "The picture comes off the player and goes up. "
				+ "wasd crosses the island, e and c zoom, shift is faster, F5 here or anywhere.")
			panel_wrapped(ci, r, y + 8, "Nothing is moved and nothing is paused: the body stays "
				+ "where it is and the world goes on, so what you are looking at is the game as it "
				+ "really is. For the whole island at once, read the survey (m) — dev mode draws it whole.")
		&"picture":
			y = panel_heading(ci, r, y, "picture")
			var where := "shots/dev/ beside the game" if DevMode.local() else ("a download" if DevMode.web() else "user://dev/pictures")
			panel_wrapped(ci, r, y, "The next frame with nothing of the slate on it, at twice its size, to %s. F4." % where)
