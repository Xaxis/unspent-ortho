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
##                            side and through a closed guard, and stalls it as a
##                            blow in the part does, for PHASE_STALL_MS
##   damp     (mod_damp)      "your blows go quieter": a blow is DAMP_NOISE as loud
##   leech    (mod_leech)     "a kill gives a charge": LEECH_CHARGES back per kill
##   capacitor(mod_capacitor) "it holds charges": every CAPACITOR_EVERY-th charged
##                            swing spends none
##   ablative (mod_ablative)  "it burns off, not you": soaks one blow that would
##                            hurt, and the module is gone
##   gyro     (mod_gyro)      "a blow does not turn you": a blow taken does not
##                            break the swing being thrown
##   clamp    (mod_clamp)     "you stay on the plate": knockback is CLAMP_KNOCK
##   lattice  (mod_lattice)   "every blow shocks": a blow that lands in a part
##                            also takes LATTICE_DAMAGE off every other body
##                            within LATTICE_REACH of it (hot: it wants a cool)
##   icelens  (mod_icelens)   "sight": the scan reads ICELENS_REACH as far

const HARMONIC_DAMAGE := 1
## How long the phase coil's opener stops a machine's work. A broken tell
## already leaves the machine as open as a dodged bite (FightSim._break_tell), so
## a stall only counts past that window (a harvester's is 1600 ms); the opener's
## stall runs past it, so the reader who opened at close quarters is out of the
## box before the machine comes again. Measured on the roused harvester met at
## its front (tests/fight/test_bouts), mean of 8 starts, gain against bare:
##   1500 -22%  1600 +26%  1650 +27%  1700 +24%  1750 +22%  1800 +21%
##   1850 +27%  1900 +35%  2000 +35%  2600 +51%
## Past the window the curve rises in knife blows (one more every ~420 ms of
## stall, 4 to 6 in the first opening), so no stall holds the 10-25% band across
## +-200 ms; 1750 holds it across +-50.
const PHASE_STALL_MS := 1750
## A kill with a leech coil fitted gives back this many charges.
const LEECH_CHARGES := 1
## A capacitor bank carries every this-many-th charged swing without a charge.
const CAPACITOR_EVERY := 3
## A blow taken with a clamp fitted throws the body this share as far.
const CLAMP_KNOCK := 0.3
## How loud a harmonic ring is against a plain blow: they hear it.
const HARMONIC_NOISE := 1.5
const DAMP_NOISE := 0.5
## A lattice discharge: how far from the body struck it jumps, and what it takes.
## A crowd is where it pays: two machines shoulder to shoulder at a gate.
const LATTICE_REACH := 1.5
const LATTICE_DAMAGE := 1
## How much further an icelens scan reads.
const ICELENS_REACH := 1.5

var harmonic := false
var phase := false
var damp := false
var leech := false
var capacitor := false
var ablative := false
var gyro := false
var clamp := false
var lattice := false
var icelens := false


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
	k.lattice = ids.has(&"mod_lattice")
	k.icelens = ids.has(&"mod_icelens")
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
