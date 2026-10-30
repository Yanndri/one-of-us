shader_type canvas_item;

// Slowly drifting dots for the background. Tune these under Shader Parameters.
// Background color and dot color (dots are a slightly lighter shade).
uniform vec4 base_color : source_color = vec4(0.247, 0.247, 0.259, 1.0);
uniform vec4 dot_color : source_color = vec4(1.0, 1.0, 1.0, 0.05);
// How many dots across the screen, how big they are, and how fast they drift.
uniform float grid = 18.0;
uniform float dot_size = 0.12;
uniform vec2 drift = vec2(0.015, 0.01);

void fragment() {
	// Keep dots round on a wide screen.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 uv = (UV + TIME * drift) * aspect * grid;
	// Offset every other row for a nicer pattern.
	uv.x += step(1.0, mod(floor(uv.y), 2.0)) * 0.5;
	vec2 cell = fract(uv) - 0.5;
	float dot_mask = 1.0 - smoothstep(dot_size, dot_size + 0.02, length(cell));
	COLOR = mix(base_color, vec4(dot_color.rgb, 1.0), dot_mask * dot_color.a);
}
