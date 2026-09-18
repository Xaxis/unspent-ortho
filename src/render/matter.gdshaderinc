// LANTERN law 1: matter is honest (docs/LOOK.md). A surface is what it is made
// of, and what has happened to it standing HERE. Included by every lit shader.
//
// Three things live here and nothing else does:
//
//   1. COLOUR SPACE. `matter_albedo()` is the ONE door a palette colour goes
//      through on its way to ALBEDO. See the block comment on it: the two
//      renderers disagree and the difference is not a detail.
//   2. WHAT A SURFACE IS. `matter_of(mark)` turns the ground MARK the vertex
//      stream already carries (GroundColors, world.gdshader) into roughness,
//      specular, metallic and how deep its own relief runs; `matter_bump()`
//      bends the normal by a world-space height field at that material's own
//      scale, so the light finds the pebbles the wash draws.
//   3. WHAT HAS HAPPENED TO IT. `matter_wear()` reads the wear map baked for
//      this world (SkyWear) and `matter_worn()` lays it on by FACE: rust down a
//      FLANK (see `matter_worn`: never the true underside, which nobody sees),
//      salt blooming white out of a seam, soot in the lee of the
//      wind, frost on what faces the sky. The same machine rusts in the bog,
//      blooms on the flat and blacks in the Burning, and it does it by world
//      position, deterministically, with no randf() anywhere.
//
// Everything here is in WORLD space. That is the whole difference between this
// file and the ink it replaced: the ink was drawn in screen pixels, so it was a
// technique laid over the picture. Matter belongs to the thing.
#ifndef MATTER_GDSHADERINC
#define MATTER_GDSHADERINC

// `sky_linear` and `sky_wear` are declared in sky.gdshaderinc with every other
// global SkyLight writes: one package owns them, and one test can find them all.

// The grain a material's marks are drawn at, pinned to the world at a fixed
// size. sky.gdshaderinc owns the projection (SKY_GRAIN, sky_px); this is the
// name the material side calls it by, because here it means "a speck of this
// surface" and not "a pixel of the picture".
vec2 matter_px(vec3 wp) {
	return sky_px(wp);
}

// sRGB -> linear, the real piecewise curve. pow(c, 2.2) is two values out at the
// bottom of every ramp, which is exactly where this game lives.
vec3 matter_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// THE ONE DOOR for a palette colour into ALBEDO or EMISSION.
//
// Measured, both renderers, a flat quad, in = (0.500, 0.250, 0.125):
//   Forward+        out = (0.737, 0.537, 0.388) = linear_to_srgb(in)
//   Compatibility   out = (0.502, 0.247, 0.114) = in
//
// So Forward+ reads ALBEDO as LINEAR light and encodes the frame for the
// display; Compatibility passes it through. The palette is sRGB display values
// (docs/ART.md, generated from a running game's screenshots). Writing them raw
// on Forward+ therefore lifts the WHOLE game about 1.5 stops and flattens every
// ramp into its top — which is a large part of why the picture went pale when
// the floor moved to Forward+, and it is not a grading choice anybody made.
//
// CLAUDE.md said "colours are sRGB palette values straight into ALBEDO; the
// Compatibility renderer does no conversion and converting made everything
// black". Both halves of that were true of Compatibility and neither is true of
// Forward+. The rule now is: every palette colour goes through this function,
// and it decides per renderer. Nothing writes ALBEDO directly.
vec3 matter_albedo(vec3 srgb) {
	return mix(srgb, matter_linear(srgb), sky_linear);
}

// A light's or a flame's colour, which is authored the same way. This is the
// door to EMISSION and nothing else, so it also carries `sky_emission`: the one
// renderer that draws a surface's own light twice under a casting sun is told
// how much of it to draw each time (sky.gdshaderinc, CompatTrim).
vec3 matter_light(vec3 srgb) {
	return matter_albedo(srgb) * sky_emission;
}

// Jittered-cell distances: (nearest, second nearest, id of nearest). Pebbles,
// broken rock, the plates a crust dries into, the seam a weld leaves.
vec3 matter_cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + vec2(ink_hash(i + g), ink_hash(i + g + vec2(5.3, 1.7))) * 0.8 + 0.1 - f;
			float d = dot(o, o);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = ink_hash(i + g + vec2(9.1, 3.3));
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

// --- What a surface is -----------------------------------------------------
//
// Keyed on the ground MARK the vertex stream already carries (GroundColors:
// 40..57 the grounds, 60..70 cliff strata, 0/255 anything a person made). One
// row per material:
//   x roughness   0 mirror .. 1 dead matte
//   y specular    how much light it returns at a glancing angle (Godot's 0..1,
//                 0.5 is the ordinary dielectric)
//   z relief      how deep its own bumps run, in world units
//   w metallic    0 for everything the land and people are made of
//
// These are the numbers a place is told apart by under one sun: wet fen and dry
// salt are not the same surface even when a grey day gives them the same value.
vec4 matter_of(int m) {
	// Anything a person made: timber, thatch, cloth, lashed rope, mud render.
	vec4 r = vec4(0.88, 0.32, 0.010, 0.0);
	if (m == 40) { r = vec4(0.93, 0.26, 0.012, 0.0); }        // TURF
	else if (m == 41) { r = vec4(0.95, 0.22, 0.020, 0.0); }   // HEATH
	else if (m == 42) { r = vec4(0.86, 0.36, 0.006, 0.0); }   // SAND
	else if (m == 43) { r = vec4(0.62, 0.60, 0.034, 0.0); }   // SHINGLE: sea-polished
	else if (m == 44) { r = vec4(0.74, 0.50, 0.014, 0.0); }   // SNOW
	else if (m == 45) { r = vec4(0.76, 0.42, 0.018, 0.0); }   // PAVEMENT: limestone
	else if (m == 46) { r = vec4(0.98, 0.12, 0.008, 0.0); }   // ASH: dead matte
	else if (m == 47) { r = vec4(0.40, 0.80, 0.024, 0.0); }   // CLINKER: slag glass
	// FEN: never dries -- but a bog is a MAT, not a mirror. It was (0.58, 0.68,
	// 0.010): the second most specular ground in the game on the flattest relief
	// in the game, and the terrain forces a level face's normal to exactly
	// vertical (world.gdshader), so every pixel of a fen had one identical BRDF
	// response. That is a flat sheet by construction, and it is why the moss read
	// as one and could not be told from the pinewood. Measured on seed 7 at noon:
	// the fen came back at luma 162 -- brighter than coast turf at 100, off a
	// wash whose own luma is 58 -- with chroma 13, because a broad specular sheen
	// returns the LIGHT's colour and not the ground's. Sphagnum is the mattest
	// thing in the landscape; what is wet here is the water BETWEEN the hummocks,
	// so the shine is bought back as relief that can catch it rather than as a
	// wash over the whole bog.
	else if (m == 48) { r = vec4(0.80, 0.38, 0.045, 0.0); }   // FEN
	// PEAT: hags are cut banks with a real lip, so it gets relief to match.
	else if (m == 49) { r = vec4(0.84, 0.34, 0.030, 0.0); }   // PEAT
	else if (m == 50) { r = vec4(0.94, 0.20, 0.014, 0.0); }   // NEEDLES
	else if (m == 51) { r = vec4(0.16, 0.95, 0.005, 0.0); }   // ICE: a mirror
	else if (m == 52) { r = vec4(0.80, 0.44, 0.040, 0.0); }   // ROCK
	else if (m == 53) { r = vec4(0.52, 0.70, 0.010, 0.0); }   // MUD: wet
	else if (m == 54) { r = vec4(0.82, 0.36, 0.008, 0.0); }   // ROAD
	else if (m == 55) { r = vec4(0.70, 0.54, 0.016, 0.0); }   // SALT: crystalline
	else if (m == 56) { r = vec4(0.50, 0.66, 0.012, 0.22); }  // SWARF: metal filings
	else if (m == 57) { r = vec4(0.86, 0.30, 0.008, 0.0); }   // PAN: dry silt
	else if (m == 58) { r = vec4(0.90, 0.28, 0.010, 0.0); }   // FRESH: broken open, so dusty and dead matte -- a glossy fracture reads as ice
	else if (m >= 60 && m <= 70) { r = vec4(0.82, 0.40, 0.050, 0.0); }  // cliff strata
	return r;
}

// Value noise, but ROTATED BETWEEN OCTAVES, and it has to be.
//
// `ink_vnoise` interpolates over a square lattice. That is invisible in a WASH,
// where only its value is read, and glaringly visible in a NORMAL, where its
// gradient is: the first version of matter_height used two plain octaves and
// the moss came back with a herringbone of diamonds about two thirds of a tile
// across ruled over the whole bog -- a grid on screen, which is the one thing
// CLAUDE.md says the eye must never be given. Turning each octave off the last
// leaves no lattice for the eye to lock onto.
float matter_fbm(vec2 p) {
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = ink_vnoise(p) * 0.5;
	p = rot * p * 2.07 + 19.0;
	v += ink_vnoise(p) * 0.28;
	p = rot * p * 2.13 + 41.0;
	v += ink_vnoise(p) * 0.15;
	p = rot * p * 2.03 + 7.0;
	v += ink_vnoise(p) * 0.07;
	return v;
}

// A material's own relief as a height in 0..1, in WORLD space, at the scale its
// marks are drawn at. Smooth on purpose: the fine speckle in the wash is
// pigment, not geometry, and differentiating it would give the light noise to
// find instead of shape.
float matter_height(int m, vec3 wp) {
	vec2 p = wp.xz;
	float h = 0.0;
	if (m == 43) {
		// SHINGLE: the pebbles themselves, on the same warped cells the wash
		// draws them in, so the stone the light rounds is the stone you see.
		vec2 qw = p + vec2(ink_vnoise(p * 0.09 + 3.0) - 0.5, ink_vnoise(p * 0.09 + 21.0) - 0.5) * 2.6;
		vec3 cd = matter_cells(qw * 6.0);
		h = 1.0 - smoothstep(0.0, 0.42, cd.x);
	} else if (m == 52 || (m >= 60 && m <= 70)) {
		// ROCK and cliff strata: broken blocks and bedding planes.
		vec3 cd = matter_cells(p * 1.6);
		h = (cd.y - cd.x) * 0.9 + matter_fbm(p * 0.7) * 0.3;
		h += sin(wp.y * 5.3 + matter_fbm(p * 0.4) * 3.0) * 0.12;
	} else if (m == 42) {
		// SAND: the same wind ripples, as ripples.
		float q = dot(p, vec2(0.6, 0.8)) * 2.4 + matter_fbm(p * 0.3) * 2.5;
		h = sin(q * 6.2832) * 0.4 + 0.5 + matter_fbm(p * 0.16 + 12.0) * 0.3;
	} else if (m == 44) {
		// SNOW: long drifts across one wind.
		vec2 wd = vec2(0.83, -0.55);
		vec2 q = vec2(dot(p, wd), dot(p, vec2(-wd.y, wd.x)));
		h = matter_fbm(q * vec2(0.30, 0.85)) * 0.7 + matter_fbm(q * vec2(0.9, 2.4)) * 0.3;
	} else if (m == 55 || m == 57) {
		// SALT and PAN: polygon plates lifted at their rims.
		vec3 cd = matter_cells(p * 0.9);
		h = smoothstep(0.0, 0.16, cd.y - cd.x);
	} else if (m == 48) {
		// FEN: hummock and hollow, which is the SHAPE of a bog and the one thing
		// it had none of -- it shared the generic growth-mat clump below, at a
		// relief of 0.010, which is to say at nothing. Sphagnum builds in mounds
		// about a tile across with standing water in the gaps, so this is one
		// broad field for the mounds and a finer one for the tussocks on them.
		// Both go through matter_fbm, which rotates between octaves, because a
		// raw ink_vnoise gradient rules a lattice over open ground -- see
		// matter_fbm's own header, where the ground it happened on was this one.
		// Squared, so the hollows are broad and flat and the mounds stand proud
		// of them, rather than the whole bog undulating like cloth.
		float mound = matter_fbm(p * 0.8) * 0.72 + matter_fbm(p * 2.4 + 31.0) * 0.28;
		h = mound * mound;
	} else if (m == 41 || m == 40 || m == 50) {
		// Anything with a mat of growth on it: clumps.
		h = matter_fbm(p * 1.7);
	} else {
		h = matter_fbm(p * 1.1);
	}
	return clamp(h, 0.0, 1.0);
}

// Bend the normal by that height field. `relief` is matter_of().z, in world
// units of rise; the slope is taken in world units too, so the bump is the same
// depth at every resolution and every zoom.
//
// NORMAL is in VIEW space in fragment(); the two screen derivatives are the
// view's own x and y, so the gradient goes straight in. The minus on y is
// because FRAGCOORD counts down the screen and view y counts up.
vec3 matter_bump(vec3 n, vec3 wp, int m, float relief) {
	if (relief <= 0.0) {
		return n;
	}
	float h = matter_height(m, wp);
	float wx = max(length(dFdx(wp)), 1e-5);
	float wy = max(length(dFdy(wp)), 1e-5);
	vec2 g = vec2(dFdx(h) / wx, -dFdy(h) / wy) * relief;
	// A slope over 1:1 is a cliff, not a grain of sand: clamp so a noisy texel
	// can never turn a face inside out.
	g = clamp(g, vec2(-1.0), vec2(1.0));
	return normalize(n - vec3(g, 0.0));
}

// --- What has happened to it ------------------------------------------------

// The land's wear at a place: R rust, G salt, B soot, A frost, each 0..1.
vec4 matter_wear(vec3 wp) {
	if (sky_view.z <= 0.0) {
		return vec4(0.0);
	}
	return texture(sky_wear, wp.xz * sky_view.z);
}

const vec3 MATTER_RUST = vec3(0.431, 0.200, 0.126);   // RUST[2]
const vec3 MATTER_RUST_HOT = vec3(0.604, 0.310, 0.157); // RUST[3]
const vec3 MATTER_SALT = vec3(0.910, 0.863, 0.753);   // LINEN[5]
const vec3 MATTER_SOOT = vec3(0.071, 0.067, 0.114);   // INK[1]
const vec3 MATTER_FROST = vec3(0.867, 0.941, 0.969);  // RIME[5]

// Lay the land's wear on a surface, by the face it is.
//
// `n_world` is the surface normal in WORLD space, `wp` the world position,
// `amount` how much of it this kind of thing takes at all (weathered timber
// takes soot and frost but hardly rusts; plate rusts hardest).
//
// Every term is a world-position hash, so the same harvester standing in the
// same bog is worn the same way in every run and after every save — and two
// harvesters twenty tiles apart are worn differently.
vec3 matter_worn(vec3 c, vec4 wear, vec3 n_world, vec3 wp, float amount, out float rough_add) {
	rough_add = 0.0;
	if (amount <= 0.001) {
		return c;
	}
	vec2 p = wp.xz;
	float up = n_world.y;
	// THE CAMERA ONLY EVER SEES TOPS AND NEAR-VERTICAL FLANKS. A wear model that
	// puts its rust on the true underside is a wear model nobody can see: the
	// first version of this did exactly that and the bog and the bone came out
	// the same machine. So "low on the thing" is anything not facing the sky,
	// and what a top face gets is what has RUN DOWN onto it from above.
	float flank = clamp(0.78 - up, 0.0, 1.0);
	float top = clamp(up, 0.0, 1.0);
	// A seam or a lip: where two panels or two plates meet, which is where a
	// crystal grows and a weld weeps. Only on something BUILT -- the land has no
	// seams, and giving it any drew a honeycomb of cells over open ground.
	float seam = 0.0;
	if (amount > 0.5) {
		vec3 cd = matter_cells(vec2(p.x + wp.y * 1.7, p.y - wp.y * 1.3) * 3.3);
		seam = smoothstep(0.11, 0.0, cd.y - cd.x);
	}
	// Streaks: long in one world direction and short across it, so what weeps
	// out of a seam RUNS instead of blooming in a circle.
	float run = ink_vnoise(vec2(p.x * 0.8 + wp.y * 2.6, p.y * 3.4));
	float grain = ink_vnoise(p * 2.7 + wp.y * 1.9);
	// 1. RUST: out of the seams and down the flanks, worst where nothing dries.
	float rust = wear.r * amount
		* clamp(flank * 1.15 + seam * 0.85 + top * run * 0.55, 0.0, 1.2)
		* smoothstep(0.30, 0.66, grain * 0.55 + run * 0.45);
	if (rust > 0.001) {
		c = mix(c, mix(MATTER_RUST, MATTER_RUST_HOT, grain), clamp(rust, 0.0, 0.88));
		rough_add += rust * 0.40;
	}
	// 2. SALT: a dry granular bloom, out of every seam and lying on every ledge.
	//    Rougher than what it grows on, which is how it reads apart from frost.
	float salt = wear.g * amount
		* clamp(seam * 1.5 + top * 0.75 + flank * 0.30, 0.0, 1.2)
		* smoothstep(0.30, 0.62, ink_vnoise(p * 1.3 + 41.0) * 0.6 + grain * 0.4);
	if (salt > 0.001) {
		c = mix(c, MATTER_SALT, clamp(salt, 0.0, 0.80));
		rough_add += salt * 0.45;
	}
	// 3. SOOT: in the lee. The wind says which side that is, so a whole field of
	//    machines is blacked down one flank and clean down the other.
	vec2 lee = normalize(sky_wind.xy + vec2(0.001, 0.0));
	float in_lee = clamp(-dot(normalize(n_world.xz + vec2(1e-4)), lee), 0.0, 1.0);
	float soot = wear.b * amount
		* clamp(in_lee * 0.85 + top * 0.70 + seam * 0.35, 0.0, 1.2)
		* smoothstep(0.24, 0.66, ink_vnoise(p * 0.9 + 7.0) * 0.6 + grain * 0.4);
	if (soot > 0.001) {
		c = mix(c, MATTER_SOOT, clamp(soot, 0.0, 0.85));
		rough_add += soot * 0.30;
	}
	// 4. FROST: on what faces the sky, and in the seams it splits. SMOOTHER than
	//    what it lies on -- it is ice -- so a frosted machine catches the light
	//    where a salted one swallows it, and the two never read alike.
	float frost = wear.a * amount
		* clamp(top * 1.25 + seam * 0.55, 0.0, 1.2)
		* smoothstep(0.26, 0.60, ink_vnoise(p * 1.9 + 61.0) * 0.65 + grain * 0.35);
	if (frost > 0.001) {
		c = mix(c, MATTER_FROST, clamp(frost, 0.0, 0.78));
		rough_add -= frost * 0.42;
	}
	return c;
}

#endif
