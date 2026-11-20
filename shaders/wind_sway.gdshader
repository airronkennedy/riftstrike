shader_type canvas_item;
// Wind sway for foliage, grass, flowers, reeds and banners: the top of each drawn sprite bends, the base stays put.
// amp is in pixels; motion = 0 turns it off (reduced motion).
uniform float amp = 2.5;
uniform float speed = 1.5;
uniform float motion = 1.0;
void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float k = pow(1.0 - UV.y, 2.0);
	float s = sin(TIME * speed + w.x * 0.013 + w.y * 0.007) + 0.35 * sin(TIME * speed * 2.3 + w.x * 0.05);
	VERTEX.x += s * amp * k * motion;
}
