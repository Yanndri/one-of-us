shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width : hint_range(1.0, 6.0) = 2.0;
varying vec4 sprite_color;

void vertex() {
	sprite_color = COLOR;
	// Make room outside the sprite rectangle, including textures with no padding.
	VERTEX += (UV * 2.0 - 1.0) * outline_width;
}

vec4 sample_sprite(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	vec2 padding = TEXTURE_PIXEL_SIZE * outline_width;
	vec2 uv = UV * (vec2(1.0) + padding * 2.0) - padding;
	vec4 base = sample_sprite(TEXTURE, uv);
	float border_alpha = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			border_alpha = max(border_alpha, sample_sprite(TEXTURE, uv + vec2(float(x), float(y)) * padding).a);
		}
	}
	float alpha = max(base.a, border_alpha * outline_color.a);
	vec3 rgb = mix(outline_color.rgb, base.rgb, base.a / max(alpha, 0.0001));
	COLOR = vec4(rgb, alpha) * sprite_color;
}
