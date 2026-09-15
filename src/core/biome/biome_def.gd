class_name BiomeDef
extends RefCounted
## Contract (M2 biomes package implements the registry and content): a landscape
## TYPE as data. Worlds compose regions from types (docs/VISION.md §3, §7.2).
## Readers (hazards, disposition, audio, sky, fight roster) use only these fields.

var id: StringName = &""
var display_name := ""
## Realm kinds it can appear in: &"surface", &"underground", &"orbital", &"era".
var realms: Array[StringName] = [&"surface"]
## Hazard id -> base strength 0..1 (cold, heat, fumes, toxins, radiation, wet, dark,
## vacuum, pressure, em, resonance, time_shear). The hazards package reads this.
var hazards: Dictionary = {}
## Roster id -> weight. The mobs spawner reads this.
var roster: Dictionary = {}
## Sentinel design id for this type (empty until designed).
var sentinel: StringName = &""
var hatch := Ink.WIND
var sound_bed: StringName = &""
var music_motif: StringName = &""
var light_tint := Color(1, 1, 1)
