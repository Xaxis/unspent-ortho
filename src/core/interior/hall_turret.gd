class_name HallTurret
extends RefCounted
## A TURRET IN THE PLAN'S HALL (docs/interiors): mounted high in a corner, it
## turns on whoever is in the hall and in its line, takes a visible moment to
## come round (`AIM_MS` -- the tell a player reads and dodges on), fires, and
## waits. The blow goes through `FightSim.strike_hero`, the one door for a hurt
## that no body struck. Pure: a system (21_doors) steps it with the time, where
## the player is and whether the line is clear, and does what it answers.
##
## It answers to the hall's warden: while the warden stands, the turrets hold the
## hall; once it is broken they stand down (the system decides that, not this).

## How far it reaches, in tiles, and how long it takes to come round and between
## shots, in ms. Slower than a settlement's turret (TurretRules), because it
## shoots at the player and a player has to be able to answer it.
const REACH := 8.0
const AIM_MS := 900.0
const EVERY_MS := 2200.0
const DMG := 2

var at := Vector2.ZERO
var facing := 0.0
## When it began coming round on the player (INF: not aiming), and when it last
## fired.
var aim_since := INF
var fired_at := -INF


func _init(pos: Vector2, face: Vector2) -> void:
	at = pos
	facing = face.angle()


## What to do now: &"idle", &"aim" (coming round, turned toward `target`) or
## &"fire" (the shot, this step). `clear` is whether the line to the target is
## open. A target that leaves its reach or its line undoes the aim.
func step(now: float, target: Vector2, clear: bool) -> StringName:
	if not clear or at.distance_to(target) > REACH:
		aim_since = INF
		return &"idle"
	facing = (target - at).angle()
	if now - fired_at < EVERY_MS:
		return &"aim" if aim_since != INF else &"idle"
	if aim_since == INF:
		aim_since = now
	if now - aim_since >= AIM_MS:
		fired_at = now
		aim_since = INF
		return &"fire"
	return &"aim"


static func blow() -> Blow:
	var b := Blow.new()
	b.windup = 0
	b.active = 0
	b.recovery = 0
	b.cooldown = 0
	b.dmg = DMG
	b.knock = 2.0
	b.knock_ms = 140
	return b
