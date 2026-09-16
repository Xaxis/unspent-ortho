class_name DevSession
## What dev mode holds on for as long as this run lasts, whatever game is up:
## the body kept fed, unseen and sheltered, the slate's edge hidden, the last
## place a warp left. The dev system (94_dev) re-asserts them every frame, since
## the game's own packages write the same fields in their turn.

static var fed := false
static var unseen := false
static var sheltered := false
static var hud_hidden := false
## Where the player stood before the last warp (Vector2.INF: none).
static var came_from := Vector2.INF


static func reset() -> void:
	fed = false
	unseen = false
	sheltered = false
	hud_hidden = false
	came_from = Vector2.INF
