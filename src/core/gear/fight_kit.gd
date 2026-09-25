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
##   leech    (mod_leech)     "a kill gives a charge": LEECH_CHARGES back per kill
##   capacitor(mod_capacitor) "it holds charges": every CAPACITOR_EVERY-th charged
##                            swing spends none
##   ablative (mod_ablative)  "it burns off, not you": soaks one blow that would
##                            hurt, and the module is gone
##   gyro     (mod_gyro)      "a blow does not turn you": a blow taken does not
##                            break the swing being thrown
##   clamp    (mod_clamp)     "you stay on the plate": knockback is CLAMP_KNOCK

const HARMONIC_DAMAGE := 1
## A kill with a leech coil fitted gives back this many charges.
const LEECH_CHARGES := 1
## A capacitor bank carries every this-many-th charged swing without a charge.
const CAPACITOR_EVERY := 3
## A blow taken with a clamp fitted throws the body this share as far.
const CLAMP_KNOCK := 0.3
## How loud a harmonic ring is against a plain blow: they hear it.
const HARMONIC_NOISE := 1.5
const DAMP_NOISE := 0.5

var harmonic := false
var phase := false
var damp := false
var leech := false
var capacitor := false
var ablative := false
var gyro := false
var clamp := false


## The kit of these fitted ids (pieces and modules alike; only modules count).
static func of(ids: Array) -> FightKit:
	var k := FightKit.new()
	k.harmonic = ids.has(&"mod_harmonic")
	k.phase = ids.has(&"mod_phase")
	k.damp = ids.has(&"mod_damp")
	k.leech = ids.has(&"mod_leech")
	k.capacitor = ids.has(&"mod_capacitor")
	k.ablative = ids.has(&"mod_ablative")
	k.gyro = ids.has(&"mod_gyro")
	k.clamp = ids.has(&"mod_clamp")
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
