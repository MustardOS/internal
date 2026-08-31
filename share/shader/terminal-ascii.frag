// Name: Terminal - Ascii Edition
// Author: MustardOS
// Version: 3

#pragma parameter columns "Character Columns" 64.0 16.0 160.0 4.0

uniform float columns;

float glyph(float d, vec2 p) {
    float dotc = 1.0 - step(0.02, dot(p - 0.5, p - 0.5));
    float h = step(0.45, p.y) * step(p.y, 0.55);
    float v = step(0.45, p.x) * step(p.x, 0.55);
    float diag1 = 1.0 - step(0.08, abs(p.x - p.y));
    float diag2 = 1.0 - step(0.08, abs(p.x - (1.0 - p.y)));
    float box = step(0.25, p.x) * step(p.x, 0.75) * step(0.25, p.y) * step(p.y, 0.75);

    float a = mix(0.0, dotc, step(0.15, d));
    float b = mix(h, clamp(h + v, 0.0, 1.0), step(0.40, d));
    float c = mix(clamp(diag1 + diag2, 0.0, 1.0), box, step(0.75, d));

    return mix(mix(a, b, step(0.30, d)), c, step(0.60, d));
}

void main() {
    float cols = max(columns, 8.0);
    const float char_ar = 2.0;

    float rows = cols / char_ar * (u_resolution.y / u_resolution.x);
    vec2 grid = vec2(cols, rows);
    vec2 cell = v_uv * grid;
    vec2 id = floor(cell);
    vec2 uv = fract(cell);

    vec2 sample_uv = (floor(((id + 0.5) / grid) * u_native_resolution) + 0.5) / max(u_native_resolution, vec2(1.0));
    vec3 col = texture2D(u_tex, sample_uv).rgb;
    float l = pow(dot(col, vec3(0.2126, 0.7152, 0.0722)), 0.85);

    gl_FragColor = vec4(col * glyph(l, uv), 1.0);
}
