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
##                            discharges LATTICE_DAMAGE, shared nearest first
##                            among the other bodies within LATTICE_REACH, for
##                            LATTICE_CHARGES (hot: it wants a cool)
##   icelens  (mod_icelens)   "sight": the scan reads ICELENS_REACH as far
##   rake     (mod_rake)      "a heavy rakes the arc": as a heavy blow is drawn,
##                            every body within RAKE_REACH and RAKE_ARC of the
##                            facing has its tell broken and its part lit
##                            (stalled open); a charger rides over it; a heavy
##                            is RAKE_NOISE as loud
##   anchor   (mod_anchor)    "stood still, rooted": ANCHOR_MS without a step and
##                            the body is rooted (Hero.rooted): a blow does not
##                            throw it, a grip does not take it; rooted, and
##                            for ANCHOR_LIFT_MS after the first step, it
##                            cannot dodge
##   lock     (mod_lock)      "a way passed is shut": a gap between two solid
##                            things no wider than LOCK_GAP that the player walks
##                            through is shut behind them to machines for
##                            LOCK_SECONDS (FightSim.lock_walls), for LOCK_CHARGES
##   undertow (mod_undertow)  "your line hauls them in": the grapple takes hold
##                            of a machine ahead and drags it one body-length
##                            in (FightSim.undertow), its tell broken and its
##                            line lost for a stall; the haul costs
##                            UNDERTOW_WIND x the grapple's wind

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
const LATTICE_REACH := 2.0
## What one discharge spends (FightRules.CHARGE).
const LATTICE_CHARGES := 1
const LATTICE_DAMAGE := 2
## How much further an icelens scan reads.
const ICELENS_REACH := 1.5
## The rake's arc: how far, how wide either side of the facing, and how loud a
## heavy blow is with it fitted. Measured with the crowd reader at a gate
## (tests/gear/test_rake): throwing what it holds back 0.6 or 1.2 tiles lost
## more bouts than holding it where it stands, so it holds.
const RAKE_REACH := 3.0
const RAKE_ARC := deg_to_rad(60.0)
const RAKE_NOISE := 1.5
## How long the player must stand without a step to be rooted by the anchor, and
## how long a root holds once they step (no dodge while it does: its cost).
const ANCHOR_MS := 600.0
const ANCHOR_LIFT_MS := 300.0
## The lock: the widest gap (edge to edge, tiles) it will shut, how long it holds,
## and what a lock spends (FightRules.CHARGE).
const LOCK_GAP := 2.2
const LOCK_SECONDS := 20.0
const LOCK_CHARGES := 1
## Only with a machine coming for the player this near (FightSim._hunted_by_machine).
const LOCK_HUNTED := 20.0
## A haul on a machine costs this many times the grapple's wind.
const UNDERTOW_WIND := 2.0

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
var undertow := false
var rake := false
var lock := false
var anchor := false


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
	k.undertow = ids.has(&"mod_undertow")
	k.rake = ids.has(&"mod_rake")
	k.lock = ids.has(&"mod_lock")
	k.anchor = ids.has(&"mod_anchor")
	return k


static func from_loadout(l: Loadout) -> FightKit:
	return of(l.all_ids()) if l != null else FightKit.new()


## A blow's noise as a share of a plain one's: `plate` when it rang off plate,
## `heavy` when it was the held blow.
func blow_noise(plate: bool, heavy: bool = false) -> float:
	var n := 1.0
	if rake and heavy:
		n *= RAKE_NOISE
	if harmonic and plate:
		n *= HARMONIC_NOISE
	if damp:
		n *= DAMP_NOISE
	return n
