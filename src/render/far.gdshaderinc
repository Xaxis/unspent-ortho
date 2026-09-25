// What the far things in the sky share: the colossi, the orbit and the falls.
// Each carried its own copy of these, marked DUPLICATE, and a copy that drifts
// draws one sky by two rules. The cloud cover they are seen through is the
// dome's own (`dome_cloud_amount`, sky_dome.gdshaderinc), because it reads the
// dome's uniforms.
#ifndef FAR_GDSHADERINC
#define FAR_GDSHADERINC

// The planet the top of the air is measured on, for the sunlit top of a far
// thing and for how far it sinks below the horizon: small, so the ember lasts an
// hour or two of the evening rather than twenty minutes.
const float R_EFF = 4.5e6;

// THE LEAST A PART MAY BE DRAWN, in pixels of radius. A shin ninety metres across
// is a quarter of a pixel at 150 km, and drawn honestly it is a dashed line that
// crawls as it walks. So anything thinner than MIN_PX is drawn that wide and let
// into the air by the share it was widened, which keeps it a continuous faint
// line whose weight is still its own. A LAMP is not let off that way: a light is
// how a thing is seen at night, so every lamp is at least LAMP_PX.
const float MIN_PX = 0.75;
const float LAMP_PX = 1.6;

// How much of a far thing's light gets through the air to the eye, per channel:
// the high air (thin, a few percent at the zenith) and the low haze (`thick`, the
// weather's fog 0..1), both along the slant (1/sin elevation, kept finite at the
// horizon), blue lost first, so a low thing reddens the way a low moon does.
vec3 far_through(vec3 d, float thick) {
	float s = max(d.y, 0.0) + 0.035;
	float tau = (0.045 + 0.10 * (1.0 + thick * 3.0)) / s;
	return exp(-tau * vec3(0.55, 0.85, 1.35)) * smoothstep(-0.01, 0.015, d.y);
}

#endif
