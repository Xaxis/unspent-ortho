class_name Geysers
extends RefCounted
## A geyser's cycle, pure: which of a land's vents are geysers, and where in its
## eruption one is at a world minute (BiomeDef.geysers). 16_vents draws it; a
## hazard reads the same answer, so what hurts and what is seen agree.
##
## One cycle of `period` world minutes: RESTING most of it, then WARNING (the
## ground hisses and a skirt of steam spreads round the mouth), then ERUPTING
## (the column rises, holds and collapses, throwing hot spray about it).

const RESTING := 0
const WARNING := 1
const ERUPTING := 2

## Shares of the cycle: the warning, then the eruption, at its end.
const WARN_SHARE := 0.12
const ERUPT_SHARE := 0.14
## How far round the mouth the spray falls, in tiles.
const SPRAY := 2.4


## Whether this vent is one of the land's geysers.
static func is_geyser(row: Dictionary, seed_value: int, id: int) -> bool:
	return not row.is_empty() and Rng.hash01(seed_value, id, 0x6E75) < float(row.get("share", 0.0))


## {stage, k}: the stage now, and how far through it (0..1).
static func state(row: Dictionary, seed_value: int, id: int, minutes: float) -> Dictionary:
	var period := maxf(1.0, float(row.get("period", 30.0)))
	var f := fposmod(minutes / period + Rng.hash01(seed_value, id, 0x6E76), 1.0)
	var erupt_at := 1.0 - ERUPT_SHARE
	var warn_at := erupt_at - WARN_SHARE
	if f >= erupt_at:
		return {"stage": ERUPTING, "k": (f - erupt_at) / ERUPT_SHARE}
	if f >= warn_at:
		return {"stage": WARNING, "k": (f - warn_at) / WARN_SHARE}
	return {"stage": RESTING, "k": f / warn_at}


## How hard the column stands at stage progress k: rising fast, holding, then
## collapsing. 0..1.
static func column(k: float) -> float:
	return smoothstep(0.0, 0.18, k) * (1.0 - smoothstep(0.7, 1.0, k))


## How hard hot spray falls at `d` tiles from an erupting mouth, 0..1: what a
## hazard reads (heat), strongest at the column's height.
static func spray_at(row: Dictionary, seed_value: int, id: int, minutes: float, d: float) -> float:
	var st := state(row, seed_value, id, minutes)
	if int(st.stage) != ERUPTING:
		return 0.0
	return column(float(st.k)) * (1.0 - smoothstep(0.5, SPRAY, d))
