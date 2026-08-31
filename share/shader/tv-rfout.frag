// Name: TV RF Output
// Author: MustardOS
// Version: 3

#pragma parameter bleed "Colour Bleed" 0.80 0.00 1.00 0.01
#pragma parameter noise "Static" 0.08 0.00 0.40 0.01
#pragma parameter ghost "Ghosting" 0.25 0.00 0.60 0.01
#pragma parameter scanline "Scanline" 0.15 0.00 0.50 0.01

uniform float bleed;
uniform float noise;
uniform float ghost;
uniform float scanline;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void main() {
    const float PI = 3.14159265;
    const vec3 LUMA = vec3(0.299, 0.587, 0.114);

    vec2 native = max(u_native_resolution, vec2(1.0));
    float px = 1.0 / native.x;
    float px2 = px * 2.0;

    vec3 c0 = texture2D(u_tex, v_uv).rgb;
    vec3 c1 = texture2D(u_tex, v_uv + vec2(px, 0.0)).rgb;
    vec3 c2 = texture2D(u_tex, v_uv - vec2(px, 0.0)).rgb;
    vec3 c3 = texture2D(u_tex, v_uv + vec2(px2, 0.0)).rgb;
    vec3 c4 = texture2D(u_tex, v_uv - vec2(px2, 0.0)).rgb;

    vec3 col = mix(vec3(dot(c0, LUMA)), (c1 + c2 + c3 + c4) * 0.25, bleed);
    col += texture2D(u_tex, v_uv - vec2(px2 * 2.0, 0.0)).r * ghost;
    col += hash(v_uv * native + u_time) * noise - noise * 0.5;
    col *= 1.0 - scanline + scanline * sin(v_uv.y * native.y * PI);

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
