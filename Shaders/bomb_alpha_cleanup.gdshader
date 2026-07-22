shader_type canvas_item;

// The supplied PNG contains very-low-alpha matte noise outside the bomb.
// Discarding only that noise keeps the artwork intact without drawing a card.
uniform float alpha_cutoff : hint_range(0.0, 0.25) = 0.08;
uniform float danger_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 sampled_texture = texture(TEXTURE, UV);
	sampled_texture.a = smoothstep(alpha_cutoff, alpha_cutoff + 0.04, sampled_texture.a);
	float red_fill = step(1.0 - danger_progress, UV.y) * sampled_texture.a;
	sampled_texture.rgb = mix(sampled_texture.rgb, vec3(0.95, 0.08, 0.035), red_fill * 0.48);
	COLOR = sampled_texture;
}
