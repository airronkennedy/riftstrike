shader_type canvas_item;
// Kingdom ground: one quad over the whole map. Terrain ids come from a tiny W x H map texture; each terrain samples
// its own tileable pixel texture (assets/kingdom/tiles, drawn at 2x). Natural terrains meet along noisy pixel-stepped
// borders; water gets depth, shimmer and animated foam; walls and cliffs get lit faces and cast a soft shadow on the
// floor below; the overworld gets slow cloud shadows. motion = 0 freezes everything (reduced motion).
// ids: 0 water 1 grass 2 forest 3 highland 4 sand 5 road 6 cobble 7 flagstone 8 carpet 9 wall 10 cliff
uniform sampler2D map_tex : filter_nearest;
uniform vec2 map_size = vec2(16.0, 16.0);
uniform int outside_id = 0;
uniform float motion = 1.0;
uniform float clouds = 0.0;
uniform sampler2D t_grass : filter_nearest, repeat_enable;
uniform sampler2D t_forest : filter_nearest, repeat_enable;
uniform sampler2D t_high : filter_nearest, repeat_enable;
uniform sampler2D t_sand : filter_nearest, repeat_enable;
uniform sampler2D t_road : filter_nearest, repeat_enable;
uniform sampler2D t_cobble : filter_nearest, repeat_enable;
uniform sampler2D t_flag : filter_nearest, repeat_enable;
uniform sampler2D t_carpet : filter_nearest, repeat_enable;
uniform sampler2D t_wall : filter_nearest, repeat_enable;
uniform sampler2D t_cliff : filter_nearest, repeat_enable;
varying vec2 wpos;

void vertex() { wpos = VERTEX; }

int tid(vec2 c) {
	ivec2 i = ivec2(floor(c));
	if (i.x < 0 || i.y < 0 || i.x >= int(map_size.x) || i.y >= int(map_size.y)) return outside_id;
	return int(texelFetch(map_tex, i, 0).r * 255.0 + 0.5);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
bool natural(int id) { return id <= 5; }
bool solid(int id) { return id == 9 || id == 10; }
vec3 tex_for(int id, vec2 uv) {
	if (id == 1) return texture(t_grass, uv).rgb;
	if (id == 2) return texture(t_forest, uv).rgb;
	if (id == 3) return texture(t_high, uv).rgb;
	if (id == 4) return texture(t_sand, uv).rgb;
	if (id == 5) return texture(t_road, uv).rgb;
	if (id == 6) return texture(t_cobble, uv).rgb;
	if (id == 7) return texture(t_flag, uv).rgb;
	if (id == 8) return texture(t_carpet, uv).rgb;
	if (id == 9) return texture(t_wall, uv).rgb;
	return texture(t_cliff, uv).rgb;
}

void fragment() {
	vec2 px = floor(wpos / 2.0) * 2.0 + 1.0; // 2 px pixel grid
	vec2 tp = px / 64.0;
	vec2 uv = px / 64.0;
	float t = TIME * motion;
	int id0 = tid(tp);
	int id = id0;
	if (natural(id0)) {
		vec2 off = vec2(vnoise(tp * 2.3), vnoise(tp * 2.3 + vec2(19.3, 7.1))) - 0.5;
		int id1 = tid(tp + off * 0.75);
		if (natural(id1)) id = id1;
	}
	vec3 col;
	if (id == 0) {
		float land = 0.0;
		float near = 0.0;
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.785398;
			vec2 d = vec2(cos(a), sin(a));
			land += (tid(tp + d * 0.55) != 0 ? 1.0 : 0.0) + (tid(tp + d * 1.1) != 0 ? 0.5 : 0.0);
			near = max(near, tid(tp + d * 0.2) != 0 ? 1.0 : 0.0);
		}
		float shallow = clamp(land / 9.0, 0.0, 1.0);
		col = mix(vec3(0.07, 0.15, 0.2), vec3(0.14, 0.3, 0.33), shallow);
		col *= 0.9 + 0.2 * vnoise(tp * 0.6 + vec2(t * 0.02, 0.0));
		float s = vnoise(px * 0.03 + vec2(t * 0.35, t * 0.12)) * vnoise(px * 0.047 - vec2(t * 0.2, -t * 0.27));
		col += step(0.4, s) * vec3(0.2, 0.3, 0.28) * (0.55 + 0.45 * sin(t * 2.0 + px.x * 0.05));
		float wave = 0.5 + 0.5 * sin(t * 1.7 + (px.x + px.y) * 0.035);
		float foam = near * step(0.45 + 0.2 * wave, vnoise(px * 0.08 + vec2(t * 0.4, -t * 0.2)) + 0.2);
		col = mix(col, vec3(0.86, 0.9, 0.84), foam * 0.85);
	} else if (solid(id0)) {
		vec2 f = fract(tp);
		bool face = !solid(tid(floor(tp) + vec2(0.5, 1.5)));
		if (face) {
			col = tex_for(id0, uv) * (1.18 - 0.6 * f.y);
			if (f.y < 0.07) col = mix(col, vec3(0.62, 0.55, 0.48), 0.6);
		} else {
			col = id0 == 9 ? vec3(0.1, 0.085, 0.075) + 0.03 * vnoise(tp * 3.0) : tex_for(3, uv) * 0.62;
		}
	} else {
		col = tex_for(id, uv);
		col *= 0.9 + 0.2 * vnoise(tp * 0.55); // macro variation hides tiling
		if (id == 4) {
			float wet = 0.0;
			for (int k = 0; k < 4; k++) { float a = float(k) * 1.5708; wet = max(wet, tid(tp + vec2(cos(a), sin(a)) * 0.4) == 0 ? 1.0 : 0.0); }
			col *= 1.0 - 0.22 * wet;
		}
		if (id != id0 && natural(id0)) col *= 0.97;
		if (id == 7) {
			// Castle / house flagstones: break up the uniform floor.
			vec2 cell = floor(tp);
			col *= 0.86 + 0.26 * hash(cell);                                    // per-slab tone
			float chk = mod(floor(tp.x * 0.5) + floor(tp.y * 0.5), 2.0);
			col = mix(col, col * vec3(1.06, 0.98, 0.88), chk * 0.45);          // 2x2 inlay pattern
			float wall = 0.0;
			float rug = 0.0;
			for (int k = 0; k < 4; k++) {
				vec2 d = vec2(cos(float(k) * 1.5708), sin(float(k) * 1.5708));
				wall = max(wall, solid(tid(tp + d * 0.7)) ? 1.0 : 0.0);
				rug = max(rug, tid(tp + d * 0.8) == 8 ? 1.0 : 0.0);
			}
			col *= 1.0 - 0.2 * wall;                                            // darker border band by the walls
			col *= 1.0 + 0.07 * rug * (1.0 - wall);                             // feet-worn strip along the carpet
			float moss = smoothstep(0.64, 0.82, vnoise(tp * 0.9 + vec2(3.7, 1.3)));
			col = mix(col, col * vec3(0.7, 0.8, 0.6), moss * 0.5 * (0.4 + 0.6 * wall)); // damp moss in corners
			float cr = abs(vnoise(tp * 3.1 + vec2(9.0, 2.0)) - 0.5);
			col *= 1.0 - 0.38 * (1.0 - smoothstep(0.0, 0.03, cr)) * step(0.6, hash(cell + 7.0)); // hairline cracks
		} else if (id == 8) {
			// Carpet runner: gold trim where it meets stone.
			float edge = 0.0;
			for (int k = 0; k < 4; k++) {
				vec2 d = vec2(cos(float(k) * 1.5708), sin(float(k) * 1.5708));
				edge = max(edge, tid(tp + d * 0.1) != 8 ? 1.0 : 0.0);
			}
			col = mix(col, vec3(0.72, 0.55, 0.26), edge * 0.55);
		}
		// contact shadow under a wall / cliff face
		if (solid(tid(floor(tp) + vec2(0.5, -0.5)))) col *= mix(0.55, 1.0, smoothstep(0.0, 0.5, fract(tp.y)));
	}
	if (clouds > 0.0) {
		float c = smoothstep(0.55, 0.78, vnoise(tp * 0.22 + vec2(t * 0.035, t * 0.012)));
		col *= 1.0 - clouds * 0.2 * c;
	}
	COLOR = vec4(col, 1.0);
}
