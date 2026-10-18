shader_type canvas_item;
render_mode blend_mix;

// Thickness field (FORMAT_RF) and per-cell colour as Kubelka-Munk K/S (FORMAT_RGBF); both sampled with
// texelFetch so no float-texture filtering support is required on the GPU.
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D color_tex : filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 grid = vec2(80.0, 52.0);
uniform vec2 cell_px = vec2(20.0, 20.0);
uniform float thick_px = 230.0;   // how tall h = 1.0 is, in pixels (for lighting)
uniform float sparkle = 0.0;
uniform float wobble = 0.0;
uniform float time = 0.0;
// style
uniform float spec_k = 0.5;
uniform float spec_pow = 70.0;
uniform float alpha_k = 1.0;      // < 1 = translucent (clear slime)
uniform float clear_k = 0.0;
uniform float metal = 0.0;
uniform float matte = 0.0;
uniform float crunch = 0.0;      // foam beads bumps + speckles
uniform float fluff = 0.0;       // soft fine texture
uniform float glow = 0.0;        // emissive, lit for a dark room
uniform float holo = 0.0;        // hue shifts with surface slope
uniform float hue_shift = 0.0;   // colour-changing slime: global hue rotation (radians)

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

vec3 fetch_c(ivec2 c) {
	ivec2 g = ivec2(grid) - 1;
	return texelFetch(color_tex, clamp(c, ivec2(0), g), 0).rgb;
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

// Bilinear colour.
vec3 sample_c(vec2 uv) {
	vec2 p = uv * grid - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	ivec2 ii = ivec2(i);
	vec3 a = mix(fetch_c(ii), fetch_c(ii + ivec2(1, 0)), f.x);
	vec3 b = mix(fetch_c(ii + ivec2(0, 1)), fetch_c(ii + ivec2(1, 1)), f.x);
	return mix(a, b, f.y);
}

void fragment() {
	vec3 s = sample_h(UV);
	float h = s.x;
	vec2 slope = vec2(s.y, s.z) / cell_px * thick_px;
	if (wobble > 0.001) {
		slope += wobble * 0.6 * vec2(sin(time * 28.0 + UV.y * 9.0), cos(time * 23.0 + UV.x * 9.0));
	}
	float speck = 0.0;
	if (crunch > 0.0) {
		vec2 buv = UV * grid * 0.035;
		float b0 = texture(noise_tex, buv).r;
		float bx = texture(noise_tex, buv + vec2(0.002, 0.0)).r;
		float by = texture(noise_tex, buv + vec2(0.0, 0.002)).r;
		float bump = smoothstep(0.58, 1.0, b0);
		slope += crunch * vec2(bx - b0, by - b0) * 120.0 * bump;
		speck = smoothstep(0.86, 0.96, b0) * crunch;
	}
	if (fluff > 0.0) {
		vec2 fuv = UV * grid * 0.16;
		float f0 = texture(noise_tex, fuv).r;
		float fx = texture(noise_tex, fuv + vec2(0.006, 0.0)).r;
		float fy = texture(noise_tex, fuv + vec2(0.0, 0.006)).r;
		slope += fluff * vec2(fx - f0, fy - f0) * 25.0;
	}
	vec3 n = normalize(vec3(-slope, 1.0));
	vec3 L = normalize(vec3(-0.45, -0.55, 0.75));
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	float ndl = max(dot(n, L), 0.0);
	float diff = mix(0.52 + 0.48 * ndl, 0.72 + 0.28 * ndl, matte);
	float spec = pow(max(dot(n, H), 0.0), spec_pow) * spec_k * (1.0 - 0.9 * matte);
	float rim = pow(1.0 - n.z, 2.0) * mix(0.25, 0.5, clear_k);

	vec3 ks = max(sample_c(UV), vec3(0.0));
	vec3 cbase = 1.0 + ks - sqrt(ks * ks + 2.0 * ks);   // Kubelka-Munk K/S -> reflectance
	if (hue_shift != 0.0 || holo > 0.0) {
		float ang = hue_shift + holo * (slope.x * 1.4 + slope.y * 0.9 + time * 0.6);
		// rotate hue around the grey axis (Rodrigues)
		vec3 k = vec3(0.57735);
		float cs = cos(ang), sn = sin(ang);
		cbase = cbase * cs + cross(k, cbase) * sn + k * dot(k, cbase) * (1.0 - cs);
		cbase = clamp(cbase, 0.0, 1.0);
	}
	vec3 base = mix(cbase * 1.06 + 0.04, cbase * 0.84, smoothstep(0.0, 1.2, h));
	base = mix(base, cbase * 0.72, metal);
	base = mix(base, base * 1.12 + 0.08, clear_k * 0.6);
	vec3 spec_col = mix(vec3(1.0), cbase * 1.2 + 0.2, metal);
	base = mix(base, base * 0.9 + 0.1, fluff * 0.6);
	vec3 col = base * diff + spec_col * spec + base * rim;
	col = mix(col, vec3(1.0), speck * 0.75);

	if (sparkle > 0.5) {
		vec2 nuv = UV * vec2(6.0, 4.0) + vec2(sin(time * 0.7), cos(time * 0.9)) * 0.05;
		float g = texture(noise_tex, nuv).r;
		float tw = 0.5 + 0.5 * sin(time * 3.0 + g * 40.0);
		col += vec3(1.0) * smoothstep(0.80, 0.93, g) * (0.5 + 0.5 * tw);
	}

	float alpha = smoothstep(0.02, 0.06, h) * alpha_k;
	float halo = 0.0;
	if (glow > 0.0) {
		// dark room: the slime is its own light; thin parts glow brighter at the edge
		vec3 g = cbase * (1.05 + 0.6 * pow(1.0 - n.z, 1.2)) + vec3(0.2) * cbase;
		col = mix(col, g + vec3(spec) * 0.6, glow);
		// soft light spill onto the table around the lump
		float hh = sample_h(UV + vec2(0.0, 0.0)).x;
		float near = sample_h(UV + vec2(0.012, 0.0)).x + sample_h(UV - vec2(0.012, 0.0)).x + sample_h(UV + vec2(0.0, 0.018)).x + sample_h(UV - vec2(0.0, 0.018)).x;
		halo = smoothstep(0.0, 0.5, near) * (1.0 - alpha) * 0.55 * glow;
	}
	// soft drop shadow: slime a little up-left of this pixel casts onto the table
	float hs = sample_h(UV - vec2(12.0, 16.0) / (grid * cell_px)).x;
	float shadow = smoothstep(0.02, 0.2, hs) * 0.22;
	vec3 table = vec3(0.0);
	float out_a = max(alpha, shadow * (1.0 - glow));
	vec3 out_rgb = mix(table, col, alpha / max(out_a, 0.0001));
	if (halo > 0.0) {
		out_rgb = mix(out_rgb, cbase, halo / max(out_a + halo, 0.0001) * (1.0 - alpha));
		out_a = max(out_a, halo);
	}
	COLOR = vec4(out_rgb, out_a);
}
