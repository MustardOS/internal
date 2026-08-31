// Name: TV Composite (NTSC) Output
// Author: MustardOS
// Version: 3

#pragma parameter bleed "Colour Bleed" 0.75 0.00 1.00 0.01
#pragma parameter scanline "Scanline" 0.10 0.00 0.50 0.01
#pragma parameter ghost "Ghosting" 0.15 0.00 0.60 0.01

uniform float bleed;
uniform float scanline;
uniform float ghost;

void main() {
    const float PI = 3.14159265;
    const vec3 LUMA = vec3(0.299, 0.587, 0.114);

    float px = 1.0 / max(u_native_resolution.x, 1.0);
    float px2 = px * 2.0;

    vec3 c0 = texture2D(u_tex, v_uv).rgb;
    vec3 c1 = texture2D(u_tex, v_uv + vec2(px, 0.0)).rgb;
    vec3 c2 = texture2D(u_tex, v_uv - vec2(px, 0.0)).rgb;
    vec3 c3 = texture2D(u_tex, v_uv + vec2(px2, 0.0)).rgb;
    vec3 c4 = texture2D(u_tex, v_uv - vec2(px2, 0.0)).rgb;

    vec3 col = mix(vec3(dot(c0, LUMA)), (c1 + c2 + c3 + c4) * 0.25, bleed);

    float phase = sin(v_uv.y * max(u_native_resolution.y, 1.0) * 1.5708 + u_time * 0.5);
    col.rg += phase * 0.04;
    col.b -= phase * 0.03;
    col += texture2D(u_tex, v_uv - vec2(px2 * 2.0, 0.0)).r * ghost;
    col *= 1.0 - scanline + scanline * sin(v_uv.y * max(u_native_resolution.y, 1.0) * PI);

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
