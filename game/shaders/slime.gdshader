shader_type canvas_item;
render_mode blend_mix;

// Height (thickness) field of the slime, one float per grid cell (FORMAT_RF, nearest).
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 grid = vec2(80.0, 52.0);     // cells
uniform vec2 cell_px = vec2(27.0, 27.0);  // size of one cell in pixels
uniform vec4 color : source_color = vec4(0.44, 0.89, 0.42, 1.0);
uniform float thick_px = 230.0;           // how tall h = 1.0 is, in pixels (for lighting)
uniform float sparkle = 0.0;
uniform float wobble = 0.0;
uniform float time = 0.0;

// Cubic B-spline weights and their derivatives.
void bspline(float t, out vec4 w, out vec4 dw) {
	float t2 = t * t;
	float t3 = t2 * t;
	w = vec4((1.0 - 3.0 * t + 3.0 * t2 - t3) / 6.0,
	         (4.0 - 6.0 * t2 + 3.0 * t3) / 6.0,
	         (1.0 + 3.0 * t + 3.0 * t2 - 3.0 * t3) / 6.0,
	         t3 / 6.0);
	dw = vec4((-3.0 + 6.0 * t - 3.0 * t2) / 6.0,
	          (-12.0 * t + 9.0 * t2) / 6.0,
	          (3.0 + 6.0 * t - 9.0 * t2) / 6.0,
	          3.0 * t2 / 6.0);
}

float fetch(ivec2 c) {
	ivec2 g = ivec2(grid) - 1;
	return texelFetch(height_tex, clamp(c, ivec2(0), g), 0).r;
}

// Smooth height and gradient (per cell) at uv in [0,1].
vec3 sample_h(vec2 uv) {
	vec2 p = uv * grid - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	vec4 wx, dwx, wy, dwy;
	bspline(f.x, wx, dwx);
	bspline(f.y, wy, dwy);
	float h = 0.0, gx = 0.0, gy = 0.0;
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			float t = fetch(ivec2(i) + ivec2(x - 1, y - 1));
			h += t * wx[x] * wy[y];
			gx += t * dwx[x] * wy[y];
			gy += t * wx[x] * dwy[y];
		}
	}
	return vec3(h, gx, gy);
}

void fragment() {
	vec3 s = sample_h(UV);
	float h = s.x;
	// slope in px/px
	vec2 slope = vec2(s.y, s.z) / cell_px * thick_px;
	if (wobble > 0.001) {
		slope += wobble * 0.6 * vec2(sin(time * 28.0 + UV.y * 9.0), cos(time * 23.0 + UV.x * 9.0));
	}
	vec3 n = normalize(vec3(-slope, 1.0));
	vec3 L = normalize(vec3(-0.45, -0.55, 0.75));
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	float diff = 0.52 + 0.48 * max(dot(n, L), 0.0);
	float spec = pow(max(dot(n, H), 0.0), 70.0) * 0.5;
	float rim = pow(1.0 - n.z, 2.0) * 0.25;

	// thin slime is lighter/translucent over the table, thick slime deeper in colour
	vec3 base = mix(color.rgb * 1.06 + 0.04, color.rgb * 0.84, smoothstep(0.0, 1.2, h));
	vec3 col = base * diff + vec3(spec) + base * rim;

	if (sparkle > 0.5) {
		vec2 nuv = UV * vec2(6.0, 4.0) + vec2(sin(time * 0.7), cos(time * 0.9)) * 0.05;
		float g = texture(noise_tex, nuv).r;
		float tw = 0.5 + 0.5 * sin(time * 3.0 + g * 40.0);
		col += vec3(1.0) * smoothstep(0.80, 0.93, g) * (0.5 + 0.5 * tw);
	}

	float alpha = smoothstep(0.025, 0.045, h);
	// soft drop shadow: slime a little up-left of this pixel casts onto the table
	float hs = sample_h(UV - vec2(12.0, 16.0) / (grid * cell_px)).x;
	float shadow = smoothstep(0.02, 0.2, hs) * 0.22;
	vec3 table = vec3(0.0);
	float out_a = max(alpha, shadow);
	vec3 out_rgb = mix(table, col, alpha / max(out_a, 0.0001));
	COLOR = vec4(out_rgb, out_a);
}
