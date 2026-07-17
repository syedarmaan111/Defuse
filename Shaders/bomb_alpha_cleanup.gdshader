shader_type canvas_item;

// The supplied PNG contains very-low-alpha matte noise outside the bomb.
// Discarding only that noise keeps the artwork intact without drawing a card.
uniform float alpha_cutoff : hint_range(0.0, 0.25) = 0.08;

void fragment() {
	vec4 sampled_texture = texture(TEXTURE, UV);
	sampled_texture.a = smoothstep(alpha_cutoff, alpha_cutoff + 0.04, sampled_texture.a);
	COLOR = sampled_texture;
}
