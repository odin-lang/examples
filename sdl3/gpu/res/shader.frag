#version 450

layout(location = 0) in  vec2 in_uv;
layout(location = 1) in  vec4 in_color;
layout(location = 0) out vec4 out_color;

// set = 2 -> fragment sampled textures (SDL_GPU SPIR-V convention)
layout(set = 2, binding = 0) uniform sampler2D tex;

// set = 3 -> fragment uniform buffers (SDL_GPU SPIR-V convention)
//
// Field order/sizes here must exactly match Odin's `Frag_Uniforms` struct
// in main.odin. Only the fields relevant to the active `mode` are
// meaningful on any given draw call.
layout(set = 3, binding = 0) uniform FragUniforms {
	int   mode;             // 0 = solid, 1 = textured, 2 = msdf text, 3 = squircle
	float screen_px_range;  // mode == 2
	vec2  half_size;        // mode == 3, pixels, local-space quad half-extents
	float corner_radius;    // mode == 3, pixels
	float squircle_blend;   // mode == 3, 0 = rounded rect, 1 = ellipse/circle
	float _pad0;
	float _pad1;
} u;

// Median of the three MSDF channels - standard multi-channel signed distance field decode step
// (see Chlumsky, "Shape Decomposition for Multi-Channel Distance Fields").
float median3(float r, float g, float b) {
	return max(min(r, g), min(max(r, g), b));
}

vec4 mtsdf(float mix_factor) {
#if true
	vec4 samp = texture(tex, in_uv);

	// 1. Reconstruct MSDF distance (median of RGB)
	float msdf_dist = max(min(samp.r, samp.g), min(max(samp.r, samp.g), samp.b));

	// 2. Reconstruct true SDF distance (alpha channel, MTSDF-specific)
	float sdf_dist = samp.a;

	// 3. Screen-space pixel range
	vec2  screen_px_range = u.screen_px_range / fwidth(in_uv);
	float px_range = max(0.5 * dot(screen_px_range, vec2(1.0)), 1.0);

	// 4. Inner (MSDF) and outer (true SDF) opacity
	float inner = px_range * (msdf_dist - 0.5) + 0.5;
	float inner_opacity = clamp(inner, 0.0, 1.0);

	float outer = px_range * (sdf_dist - 0.5) + 0.5;
	float outer_opacity = clamp(outer, 0.0, 1.0);

	// 5. Mix
	return mix(in_color * inner_opacity, in_color * outer_opacity, mix_factor);
#else
        vec3  msdf = texture(tex, in_uv).rgb;
        float sd   = median3(msdf.r, msdf.g, msdf.b);
        float screen_px_dist = u.screen_px_range * (sd - 0.5);
        float coverage = clamp(screen_px_dist + 0.5, 0.0, 1.0);
        return vec4(in_color.rgb, in_color.a * coverage);
#endif
}

// Signed distance to an axis-aligned rounded box, centered at the origin.
// b = half-extents, r = corner radius. Standard Inigo Quilez formulation.
float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Cheap approximate signed distance to an axis-aligned ellipse, centered at
// the origin, with half-extents b. Not exact (a true ellipse SDF needs an
// iterative solve), but plenty accurate near the boundary, which is all
// that matters for antialiasing - and it degenerates to an exact circle SDF
// when b.x == b.y.
float sd_ellipse_approx(vec2 p, vec2 b) {
	return (length(p / b) - 1.0) * min(b.x, b.y);
}

void main() {
	if        (u.mode == 0) {
		// MTSDF glyph: reconstruct a smooth per-pixel coverage value from the
		// distance field and use it as alpha, tinted by the vertex color.
		out_color = mtsdf(0.8);

	} else if (u.mode == 1) {
		// Squircle: blend a rounded-box SDF and an ellipse SDF, then
		// antialias the zero crossing using screen-space derivatives so it
		// stays crisp at any size without needing a precomputed px range.
		// `in_uv` was repurposed by draw_squircle to carry local pixel-space
		// position rather than a texture coordinate.
		vec2  p = in_uv;
		float d_box     = sd_round_box(p, u.half_size, u.corner_radius);
		float d_ellipse = sd_ellipse_approx(p, u.half_size);
		float d = mix(d_box, d_ellipse, u.squircle_blend);

		float aa = max(fwidth(d), 1e-4);
		float coverage = 1.0 - smoothstep(-aa, aa, d);
		out_color = vec4(in_color.rgb, in_color.a * coverage);
		// // Flat colored rectangle - vertex color carries everything.
		// out_color = in_color;
	} else if (u.mode == 2) {
		// Regular textured quad, straight alpha blended.
		vec4 tex_color = texture(tex, in_uv);
		out_color = tex_color * in_color;
	}
}