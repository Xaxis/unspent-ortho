class_name FightKit
extends RefCounted
## What the fitted kit changes in a fight: the modules' decisions
## (ModifierTable) made true where a blow lands. Pure: built from the ids fitted
## (`of`, `from_loadout`), handed to the Hero by 54_gear, and read by FightSim
## as it lands a blow and by 32_disposition as it counts a blow's noise.
##
##   harmonic (mod_harmonic)  "it rings their plate": a blow that rings off plate
##                            still takes HARMONIC_DAMAGE, and rings louder
##   phase    (mod_phase)     "it reads the working part through the plate": the
##                            first blow on each body reaches its part from any
##                            side and through a closed guard; it hurts, and
##                            does not stall the machine
##   damp     (mod_damp)      "your blows go quieter": a blow is DAMP_NOISE as loud

const HARMONIC_DAMAGE := 1
## How loud a harmonic ring is against a plain blow: they hear it.
const HARMONIC_NOISE := 1.5
const DAMP_NOISE := 0.5

var harmonic := false
var phase := false
var damp := false


## The kit of these fitted ids (pieces and modules alike; only modules count).
static func of(ids: Array) -> FightKit:
	var k := FightKit.new()
	k.harmonic = ids.has(&"mod_harmonic")
	k.phase = ids.has(&"mod_phase")
	k.damp = ids.has(&"mod_damp")
	return k


static func from_loadout(l: Loadout) -> FightKit:
	return of(l.all_ids()) if l != null else FightKit.new()


## A blow's noise as a share of a plain one's: `plate` when it rang off plate.
func blow_noise(plate: bool) -> float:
	var n := 1.0
	if harmonic and plate:
		n *= HARMONIC_NOISE
	if damp:
		n *= DAMP_NOISE
	return n
