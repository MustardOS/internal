// Name: Sharpen
// Author: MustardOS
// Version: 3

#pragma parameter strength "Sharpen Strength" 0.80 0.00 3.00 0.05

uniform float strength;

void main() {
    vec2 px = 1.0 / max(u_native_resolution, vec2(1.0));
    vec3 c = texture2D(u_tex, v_uv).rgb;

    vec3 blur = (texture2D(u_tex, v_uv + vec2(px.x, 0.0)).rgb
               + texture2D(u_tex, v_uv - vec2(px.x, 0.0)).rgb
               + texture2D(u_tex, v_uv + vec2(0.0, px.y)).rgb
               + texture2D(u_tex, v_uv - vec2(0.0, px.y)).rgb) * 0.25;

    gl_FragColor = vec4(clamp(c + (c - blur) * strength, 0.0, 1.0), 1.0);
}
