shader_type canvas_item;
// Scene transition: an iris that closes on a point (radius in screen heights), or a plain fade.
uniform float radius = 3.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.0;
uniform bool use_fade = false;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float a = use_fade ? fade : smoothstep(radius - 0.015, radius + 0.015, length(p));
	COLOR = vec4(0.07, 0.05, 0.04, a);
}
