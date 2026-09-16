class_name HazardCues
## What a pressure looks and sounds like on a body, so it is answered before it
## hurts (docs/ART.md §7: every mark is drawn, nothing bounces like a physics
## engine). Pure: the cue says what to draw and how often; 52_hazards draws it.
##
##   mark   &"breath" a pale puff at the head that rises and thins
##          &"shimmer" heat lifting off the ground around the feet
##          &"cough"  a short puff and a shudder
##          &"tick"   a few cold bright pixels: a counter, a charge in the air
##          &"drip"   water coming off the body
##          &"ring"   a dashed ink ring: the stone sounding through the body
##          &"" nothing drawn (the dark says itself)
##   shiver the figure shudders with it
##   sound  the name emitted (SoundNames resolves it)
##   colour, tone  the Palette ramp and the step of it the mark is drawn in. The
##          step matters: a cue has to read against the ground it is drawn over,
##          so breath in the snow is a mid blue and not the white it would be.

const CUES := {
	&"cold": {"mark": &"breath", "sound": &"hazard_cold", "shiver": true, "colour": &"rime", "tone": 2},
	&"heat": {"mark": &"shimmer", "sound": &"hazard_heat", "shiver": false, "colour": &"ember", "tone": 4},
	&"fumes": {"mark": &"cough", "sound": &"hazard_fumes", "shiver": true, "colour": &"ash", "tone": 1},
	&"toxins": {"mark": &"cough", "sound": &"hazard_fumes", "shiver": true, "colour": &"moss", "tone": 4},
	&"radiation": {"mark": &"tick", "sound": &"hazard_em", "shiver": false, "colour": &"lens", "tone": 3},
	&"em": {"mark": &"tick", "sound": &"hazard_em", "shiver": false, "colour": &"found", "tone": 4},
	&"wet": {"mark": &"drip", "sound": &"hazard_wet", "shiver": true, "colour": &"brine", "tone": 3},
	&"resonance": {"mark": &"ring", "sound": &"hazard_ring", "shiver": true, "colour": &"slate", "tone": 1},
	&"pressure": {"mark": &"cough", "sound": &"hazard_ring", "shiver": true, "colour": &"slate", "tone": 1},
	&"vacuum": {"mark": &"cough", "sound": &"hazard_ring", "shiver": true, "colour": &"rime", "tone": 2},
	&"time_shear": {"mark": &"tick", "sound": &"hazard_ring", "shiver": false, "colour": &"bloom", "tone": 3},
	&"dark": {"mark": &"", "sound": &"", "shiver": false, "colour": &"ink", "tone": 2},
}

## Seconds between cues when a pressure is only felt, and when it is at its worst.
const SLOW_BEAT := 5.0
const FAST_BEAT := 1.4


static func cue(id: StringName) -> Dictionary:
	return CUES.get(id, {"mark": &"tick", "sound": &"", "shiver": false, "colour": &"ash"})


## Cues come faster the harder the pressure presses; below Hazards.FELT, never.
static func beat(value: float) -> float:
	if value < Hazards.FELT:
		return INF
	var t := clampf((value - Hazards.FELT) / (1.0 - Hazards.FELT), 0.0, 1.0)
	return lerpf(SLOW_BEAT, FAST_BEAT, t)


## The colour ramp a cue's mark is drawn from (Palette, through UiIcons.ramp).
static func ramp(id: StringName) -> Array[Color]:
	return UiIcons.ramp(StringName(cue(id).get("colour", &"ash")))


## The colour a cue's mark is drawn in: the step of its ramp that reads against
## the ground this hazard belongs to.
static func colour(id: StringName) -> Color:
	var r := ramp(id)
	return r[clampi(int(cue(id).get("tone", 2)), 0, r.size() - 1)]
