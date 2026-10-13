// COMING TO (UiWaking, 48_wake): the frame as his eyes give it on the first
// morning. Black; then a slit that opens across the middle and falls shut; the
// world swimming, doubled where the eyes will not agree, drained of colour and
// dark at the edges; each opening wider and sharper until he is awake and this
// draws the world exactly as it is.
//
// `open` 0 shut .. 1 wide, `focus` 0 swimming .. 1 sharp, `light` 0 drained and
// dark .. 1 the world's own.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float open = 0.0;
uniform float focus = 0.0;
uniform float light = 0.0;

// Twelve taps on two rings: soft enough to swim, cheap enough for the web.
vec3 swim(vec2 uv, vec2 r) {
	vec3 s = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		float k = (i % 2 == 0) ? 1.0 : 0.5;
		s += texture(screen, uv + vec2(cos(a), sin(a)) * r * k).rgb;
	}
	return s / 12.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float blur = 1.0 - focus;
	// Round on the screen, not stretched with it.
	vec2 r = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) * 0.018 * blur;
	vec3 c = blur > 0.01 ? swim(uv, r) : texture(screen, uv).rgb;
	if (blur > 0.01) {
		vec3 twin = swim(uv + vec2(0.03, 0.006) * blur, r);
		c = mix(c, twin, 0.45 * blur);
	}
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(grey), c, light) * mix(0.3, 1.0, light);
	// The lids: an almond across the middle that the corners close first.
	vec2 p = uv - 0.5;
	float edge = abs(p.y) + p.x * p.x * 0.9;
	float lid = open * 0.85;
	float seen = 1.0 - smoothstep(lid - 0.05 - 0.12 * blur, lid, edge);
	float vignette = 1.0 - smoothstep(0.3, 0.8, length(p * vec2(1.0, 1.4))) * (1.0 - light) * 0.85;
	COLOR = vec4(c * seen * vignette, 1.0);
}
