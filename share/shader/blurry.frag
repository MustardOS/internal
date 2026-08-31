// Name: Blurry
// Author: MustardOS
// Version: 3

#pragma parameter radius "Blur Radius" 2.00 0.50 8.00 0.25

uniform float radius;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

void main() {
    vec2 px = 1.0 / native_res();
    vec2 o = vec2(px.x * radius, 0.0);
    vec2 o2 = o * 2.0;

    vec3 col = texture2D(u_tex, clamp(v_uv - o2, 0.0, 1.0)).rgb * 0.10
             + texture2D(u_tex, clamp(v_uv - o,  0.0, 1.0)).rgb * 0.20
             + texture2D(u_tex, v_uv).rgb * 0.40
             + texture2D(u_tex, clamp(v_uv + o,  0.0, 1.0)).rgb * 0.20
             + texture2D(u_tex, clamp(v_uv + o2, 0.0, 1.0)).rgb * 0.10;

    gl_FragColor = vec4(col, 1.0);
}
