shader_type canvas_item;
render_mode unshaded;
// Kingdom post pass over the world (UI sits on a higher layer and stays sharp):
// tilt-shift depth of field, a cheap bloom, slanted god rays, per-area colour grading and a warm vignette.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float tilt = 1.0;
uniform float focus_center = 0.52;
uniform float focus_width = 0.26;
uniform float bloom = 0.55;
uniform float bloom_threshold = 0.72;
uniform vec3 tint = vec3(1.0);
uniform float saturation = 1.08;
uniform float contrast = 1.06;
uniform float warmth = 0.0;
uniform float vignette = 0.5;
uniform float aspect = 1.0;
uniform float rays = 0.0;
uniform vec3 ray_color = vec3(1.0, 0.85, 0.6);
uniform float motion = 1.0;

const vec2 P[12] = vec2[](vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 base = texture(screen_tex, uv).rgb;
	float d = abs(uv.y - focus_center);
	float amt = smoothstep(focus_width, focus_width + 0.32, d) * tilt;
	float r = mix(5.0, 9.0, amt) * max(1.0, 1.0 / (px.y * 900.0));
	vec3 acc = vec3(0.0);
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		vec3 s = texture(screen_tex, uv + P[i] * px * r).rgb;
		acc += s;
		glow += max(s - vec3(bloom_threshold), vec3(0.0));
	}
	acc /= 12.0;
	glow /= 12.0;
	vec3 col = mix(base, acc, amt * 0.8);
	col += glow * bloom * 1.6;
	if (rays > 0.0) {
		float a = uv.x * aspect * 0.75 + uv.y * 0.55;
		float r1 = sin(a * 8.0 + TIME * 0.12 * motion) * 0.5 + 0.5;
		float r2 = sin(a * 21.0 - TIME * 0.07 * motion + 1.3) * 0.5 + 0.5;
		float shaft = pow(r1 * r2, 2.5) * smoothstep(1.05, 0.05, uv.y);
		col += ray_color * shaft * rays;
	}
	col *= tint;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col += vec3(warmth, warmth * 0.35, -warmth) * 0.25;
	vec2 p = (uv - 0.5) * vec2(min(aspect, 1.6), 1.0);
	col *= 1.0 - vignette * smoothstep(0.32, 0.92, length(p) * 1.1);
	COLOR = vec4(col, 1.0);
}
