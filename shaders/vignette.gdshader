shader_type canvas_item;
// Soft warm vignette over the whole kingdom view (Airron's Fall ember dark).
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float inner : hint_range(0.0, 1.0) = 0.42;
uniform float aspect = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(min(aspect, 1.6), 1.0);
	float v = smoothstep(inner, 0.95, length(p) * 1.15);
	COLOR = vec4(0.05, 0.03, 0.02, v * strength);
}
