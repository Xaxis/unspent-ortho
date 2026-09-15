class_name SoundBuses
## The bus layout, made in code from SoundMix.BUSES (no .tres): Music, SFX
## (with SfxFar, dull and wet, for one-shots at a distance), Ambience, Machines
## (low-pass and room set live from the distance of the one machine heard) and
## UI. Master ends in a limiter so thunder over a storm never clips.
## Idempotent: existing buses are found by name and brought to spec.

## Machines bus effect slots.
const MACHINE_LOWPASS := 0
const MACHINE_ROOM := 1


static func ensure() -> void:
	for row: Array in SoundMix.BUSES:
		var name: StringName = row[0]
		var idx := AudioServer.get_bus_index(name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, row[1])
		AudioServer.set_bus_volume_db(idx, float(row[2]))
	_ensure_effects(&"Master", func() -> Array:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		return [lim])
	_ensure_effects(&"SfxFar", func() -> Array:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2400.0
		var room := AudioEffectReverb.new()
		room.room_size = 0.6
		room.damping = 0.6
		room.wet = 0.22
		room.dry = 0.9
		room.hipass = 0.2
		return [lp, room])
	_ensure_effects(&"Machines", func() -> Array:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 16000.0
		var room := AudioEffectReverb.new()
		room.room_size = 0.7
		room.damping = 0.5
		room.wet = 0.05
		room.dry = 1.0
		room.hipass = 0.25
		return [lp, room])


## Adds the effects made by `make` unless the bus already has that many.
static func _ensure_effects(bus: StringName, make: Callable) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var fx: Array = make.call()
	if AudioServer.get_bus_effect_count(idx) >= fx.size():
		return
	for e: AudioEffect in fx:
		AudioServer.add_bus_effect(idx, e)


static func machine_lowpass() -> AudioEffectLowPassFilter:
	var idx := AudioServer.get_bus_index(&"Machines")
	if idx < 0 or AudioServer.get_bus_effect_count(idx) <= MACHINE_LOWPASS:
		return null
	return AudioServer.get_bus_effect(idx, MACHINE_LOWPASS) as AudioEffectLowPassFilter


static func machine_room() -> AudioEffectReverb:
	var idx := AudioServer.get_bus_index(&"Machines")
	if idx < 0 or AudioServer.get_bus_effect_count(idx) <= MACHINE_ROOM:
		return null
	return AudioServer.get_bus_effect(idx, MACHINE_ROOM) as AudioEffectReverb
