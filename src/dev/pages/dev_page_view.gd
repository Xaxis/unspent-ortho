class_name DevPageView
extends DevPage
## What is seen: the camera's zoom, the readout on the glass's edge, the slate's
## edge hidden, a clean picture, and leaving for the title.

const ZOOMS: Array[float] = [8.0, 11.0, 15.0, 20.0, 26.0, 34.0, 46.0]


func heading() -> String:
	return "VIEW"


func rows() -> Array[Dictionary]:
	return [
		item(&"zoom", "zoom", str(snappedf(game.camera.view_height, 0.1)), {"steps": true}),
		item(&"readout", "readout on the edge", "yes" if DevMode.readout else "no", {"steps": true}),
		item(&"hud", "slate's edge", "hidden" if DevSession.hud_hidden else "shown", {"steps": true}),
		item(&"picture", "a picture, nothing of the slate"),
		header(""),
		item(&"title", "to the title", "", {"tone": "warn"}),
	]


func confirm(row: Dictionary) -> void:
	match row.id:
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
		_:
			return
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 8
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
		&"picture":
			y = panel_heading(ci, r, y, "picture")
			var where := "shots/dev/ beside the game" if DevMode.local() else ("a download" if DevMode.web() else "user://dev/pictures")
			panel_wrapped(ci, r, y, "The next frame with nothing of the slate on it, at twice its size, to %s. F4." % where)
