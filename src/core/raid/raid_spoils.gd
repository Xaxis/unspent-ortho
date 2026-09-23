class_name RaidSpoils
## What is left lying about after the machines have been (docs/VISION.md),
## declared into the one loot economy (src/core/loot/drops.gd).
##
## Two tables, and both of them keep an id of their own with `of` left EMPTY,
## because neither is a body: a holding is LOOTED and a record is TAKEN OFF one.
## Naming a roster kind there would hand the same goods out again every time
## something of that kind died (Drops' own header says so).
##
##   razed_holding   what the party could not carry, left in a razed yard
##   filed_record    what comes off a machine killed with a reading on it

const RAZED := &"razed_holding"
const RECORD := &"filed_record"

## The record itself: a machine's own account of a place, in the machines' hands.
## Worth carrying because it is proof, and because a plan that has lost one of
## its records is a plan less sure of what it knew (Attention: &"stopped").
const RECORD_ITEM := &"record"

static var _declared := false


## Called by 48_raids on setup and by tests. The loot tables are static and a
## test may have cleared them, so it is safe to call again.
static func declare() -> void:
	Drops.declare(RAZED, [
		# The bones of what stood there: timber out of the frames, plate off
		# whatever was mended, and stock the machines trod into the ground.
		{"item": &"timber", "count": Vector2i(1, 3)},
		{"item": &"scrap", "count": Vector2i(2, 5)},
		{"item": &"rag", "chance": 0.7, "count": Vector2i(1, 2)},
		{"item": &"spoil", "chance": 0.5, "count": Vector2i(1, 2)},
	])
	Drops.declare(RECORD, [
		{"item": RECORD_ITEM, "chance": 1.0, "rarity": Rarity.UNCOMMON},
	])
	_declared = true


static func declared() -> bool:
	return _declared


## What a razed holding leaves, rolled once per holding so the same ruin always
## holds the same things however often the game is loaded.
static func razed(seed_value: int, settlement_id: int, land: StringName = &"") -> Array:
	return Drops.roll(RAZED, seed_value, settlement_id, land)


## What comes off a carrier killed with a reading on it.
static func record(seed_value: int, notice_id: int) -> Array:
	return Drops.roll(RECORD, seed_value, notice_id)
