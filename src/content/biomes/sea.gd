## The sea. Not a landscape you walk: the water every realm's surface is cut
## out of, and the type index 0 that means "no land here". It carries a climate
## and a bed so a boat, a drowned street and a frost sea have something to read.

static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"sea"
	d.display_name = "sea"
	d.order = -1
	d.sea = true
	d.style_note = "Chart depth bands with inked edges; the land's washes end in it."
	d.realms = [&"surface"]
	d.hatch = Ink.NONE
	d.relief = {
		&"base": 0.0, &"hills": 0.0, &"ridge": 0.0, &"terrace": 0.0, &"valley": 0.5,
		&"rain": 0.0, &"temp": 0.5, &"moist": 1.0, &"cliff": 0.0,
	}
	d.grade = Vector4(-0.1, 0.0, 0.04, 0.0)
	d.weather = [
		[Weather.CLEAR, 22, 0.0], [Weather.GREY, 30, 0.0], [Weather.RAIN, 20, 0.7],
		[Weather.FOG, 14, 0.0], [Weather.STORM, 14, 0.5],
	]
	d.mist = 0.2
	d.hazards = {&"wet": 1.0}
	d.sound_bed = &"bed_wind"
	d.music_motif = &"coast"
	return d
