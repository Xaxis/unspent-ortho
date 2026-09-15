class_name SoundBuses
## The bus layout, made in code from SoundMix.BUSES (no .tres): Music, World
## (SFX with SfxFar under it, dull and wet for one-shots at a distance, and
## Ambience), Machines (low-pass and room set live from the distance of the one
## machine heard) and UI. World has a low-pass a notebook page closes over it.
## Master ends in a limiter so thunder over a storm never clips.
## Idempotent: existing buses are found by name, moved after the bus they send
## to if they came first, and brought to spec.

## Machines bus effect slots.
const MACHINE_LOWPASS := 0
const MACHINE_ROOM := 1
## World bus effect slot.
const WORLD_LOWPASS := 0
## Music bus effect slot.
const MUSIC_LOWPASS := 0


static func ensure() -> void:
	for row: Array in SoundMix.BUSES:
		var name: StringName = row[0]
		var idx := AudioServer.get_bus_index(name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
		var target := AudioServer.get_bus_index(row[1])
		if target >= idx:
			# A bus may only send to one before it: move this one to the end.
			AudioServer.move_bus(idx, AudioServer.bus_count)
			idx = AudioServer.get_bus_index(name)
		AudioServer.set_bus_send(idx, row[1])
		AudioServer.set_bus_volume_db(idx, float(row[2]))
	_ensure_effects(&"Master", func() -> Array:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		return [lim])
	_ensure_effects(&"World", func() -> Array:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20000.0
		return [lp])
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
	# The score's low-pass: the conductor closes it at night and in fog.
	_ensure_effects(&"Music", func() -> Array:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 14000.0
		return [lp])
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
	set_muffle(0.0)


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


static func music_lowpass() -> AudioEffectLowPassFilter:
	var idx := AudioServer.get_bus_index(&"Music")
	if idx < 0 or AudioServer.get_bus_effect_count(idx) <= MUSIC_LOWPASS:
		return null
	return AudioServer.get_bus_effect(idx, MUSIC_LOWPASS) as AudioEffectLowPassFilter


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


## Close a page over the world (0 open air .. 1 fully muffled). The filter is
## switched off when there is nothing to muffle, so it costs nothing.
static func set_muffle(amount: float) -> void:
	var idx := AudioServer.get_bus_index(&"World")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, SoundMix.muffle_db(amount))
	if AudioServer.get_bus_effect_count(idx) <= WORLD_LOWPASS:
		return
	var lp := AudioServer.get_bus_effect(idx, WORLD_LOWPASS) as AudioEffectLowPassFilter
	lp.cutoff_hz = SoundMix.muffle_cutoff(amount)
	AudioServer.set_bus_effect_enabled(idx, WORLD_LOWPASS, amount > 0.01)
