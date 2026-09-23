// The light a person stands in, for person.gdshader and person_rim.gdshader.
// People are the warm moving thing (docs/LOOK.md sections 5 and 6): a figure in a
// fire's pool takes the fire's colour on its washes and on its rim, instead of
// the cold grade and the moon winning. Include after sky.gdshaderinc.
#ifndef PERSON_LIGHT_GDSHADERINC
#define PERSON_LIGHT_GDSHADERINC

// The strongest lamp, fire or lantern near a point, reached `reach` times past
// its pool (a figure's head stands above the ground the pool is measured on):
// rgb its colour, a its level 0..1; `at` its position.
vec4 person_nearest_light(vec3 p, float reach, out vec3 at) {
	vec4 best = vec4(0.0);
	at = p;
	for (int i = 0; i < 4; i++) {
		vec4 l1 = sky_lamps[i];
		float a1 = sky_omni(p, vec4(l1.xyz, l1.w * reach));
		if (a1 > best.a && dot(neon_lamp_rgb[i].rgb, vec3(1.0)) > 0.01) {
			best = vec4(neon_lamp_rgb[i].rgb, a1);
			at = l1.xyz;
		}
		vec4 l2 = sky_lamps2[i];
		float a2 = sky_omni(p, vec4(l2.xyz, l2.w * reach));
		if (a2 > best.a && dot(neon_lamp_rgb2[i].rgb, vec3(1.0)) > 0.01) {
			best = vec4(neon_lamp_rgb2[i].rgb, a2);
			at = l2.xyz;
		}
	}
	return best;
}

// The light's colour laid on a wash in whole steps, never a gradient: `level` is
// the stepped pool (0, 0.5 in the ring, 1 in the core). Past the grade, so a
// fire is warm on a face even where the land's grade is bleak and cool. The
// wash keeps the value the sky gave it (a pale coat is not blown to white by a
// cold lantern) and takes its hue from its own colour carried by the light's;
// the core lifts it a little, the way the ground's pool shows the page.
vec3 person_in_light(vec3 graded, vec3 base, vec4 lamp, float level) {
	if (level <= 0.0) {
		return graded;
	}
	const vec3 L = vec3(0.299, 0.587, 0.114);
	// A warm light carries its hue onto a wash; the cold LED of the lantern only
	// lifts it, so it never turns a brown coat to olive or a person to a machine.
	float warmth = clamp(lamp.r - lamp.b + 0.4, 0.0, 1.0);
	vec3 hue = base * mix(vec3(1.0), 0.5 + lamp.rgb * 0.7, mix(0.2, 1.0, warmth));
	float want = dot(graded, L) * (level >= 0.99 ? 1.08 : 1.0);
	vec3 lit = hue * (want / max(dot(hue, L), 0.004));
	return mix(graded, lit, level >= 0.99 ? 0.8 : 0.5);
}

#endif
