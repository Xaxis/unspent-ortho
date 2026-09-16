// FOUND: the machines and everything taken off them (pylons, plate on roofs,
// salvage kit). Drawn by a ruler: a flat wash, ONE hard shade step, NO hatching,
// no paper grain, no wobble. They should look like they do not belong to the
// drawing, because they do not. Working parts glow (emission_strength > 0).
shader_type spatial;
render_mode cull_back, specular_disabled;

#define SKY_FOUND
#include "res://src/render/sky.gdshaderinc"

uniform vec3 shade_tint = vec3(0.58, 0.56, 0.74);
uniform float emission_strength = 0.0;
// Machines keep their light at night: their wash is dimmed less than the land.
uniform float night_keep = 0.35;

// A blow's paper-white, as a sphere in world space (docs/ART.md §7). Only the
// part that was struck goes to paper: a machine that whites out whole proves
// nothing about where the blow landed, hides its own amber working part at the
// exact moment the player is aiming at it, and is the biggest thing in the
// frame — all three of the things a hit mark must never be. `flash_r` 0 is
// every draw but the sixty milliseconds after a hit. MobFx.set_flash writes
// these into a copy of the struck body's material, never into a shared one.
uniform vec3 flash_at = vec3(0.0);
uniform float flash_r = 0.0;
uniform vec3 flash_col = vec3(0.9098, 0.8627, 0.7529);

varying vec3 world_pos;

// The ink floor (docs/ART.md section 6: "nothing is pure black"). The law is
// about the page, not about who drew on it: the inside of a hull or a cavity
// under plate, graded down at night, has to stop where the pen does, exactly as
// the land does. Palette.INK[2] and its luma, the same two numbers world.gdshader
// carries; tests/render/test_ink_floor.gd holds the two shaders to each other.
const vec3 FOUND_INK = vec3(0.1176, 0.1098, 0.1804);
const float INK_FLOOR = 0.1203;
vec3 ink_floor(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(FOUND_INK, c, clamp(l / INK_FLOOR, 0.0, 1.0));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 tinted = sky_apply(c, world_pos, TIME);
	ALBEDO = ink_floor(mix(tinted, c, night_keep * (1.0 - clamp(dot(tinted, vec3(0.333)) / max(dot(c, vec3(0.333)), 1e-3), 0.0, 1.0))));
	// Neon on the FOUND: vertex alpha below 1 is a light built into the machine.
	// 0.5..0.98 a steady strip (brighter lower); below 0.5 a beacon that blinks
	// on a slow machine beat, each beacon at its own phase.
	float glow = 0.0;
	if (COLOR.a < 0.98) {
		if (COLOR.a >= 0.5) {
			glow = (1.0 - COLOR.a) * 5.0;
		} else {
			float beat = fract(TIME * 0.45 + dot(floor(world_pos.xz * 0.5), vec2(0.37, 0.61)));
			glow = step(beat, 0.18) * (1.0 - COLOR.a * 2.0) * 6.0 + 0.15;
		}
	}
	// The machines' own light runs on their power: a lightning strike stutters it.
	EMISSION = (c * emission_strength + c * glow) * sky_power() + neon_skyglow(c);
	// The blow's paper, hard-edged because FOUND is drawn with a ruler. Laid as
	// EMISSION over a black albedo so it lands on exactly the page's white
	// whatever the light is doing, the way the flat flash material used to.
	// It whitens PLATE and never LIGHT: emissive geometry and the machine's own
	// built-in strips keep burning through their own hit mark, which is the
	// whole point of it — the player is aiming at the amber part, and the blow
	// that lands must not be the thing that hides it.
	if (flash_r > 0.0 && emission_strength <= 0.0 && COLOR.a >= 0.98
			&& distance(world_pos, flash_at) < flash_r) {
		ALBEDO = vec3(0.0);
		EMISSION = flash_col;
	}
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.05, dot(NORMAL, LIGHT)) * step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint * sky_shade.rgb, vec3(1.0), lit) / PI;
	} else {
		// The lamp's pool in the land's own two hard steps and stippled rim.
		float a = sky_pool(clamp(ATTENUATION * step(-0.2, dot(NORMAL, LIGHT)), 0.0, 1.0), world_pos);
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
