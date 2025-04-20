shader_type canvas_item;

// Taken from https://godotshaders.com/shader/rotate-texture/ but modified a bit and removed the texture and clockwise options

uniform float speed : hint_range(0.1, 20.0) = 1.0;

vec2 rotate(vec2 uv, float angle) {
	uv -= 0.5;
	uv *= mat2(vec2(sin(angle), -cos(angle)), vec2(cos(angle), sin(angle)));
	return uv + 0.5;
}

void fragment() {
	COLOR = texture(TEXTURE, rotate(UV, TIME * speed));
}