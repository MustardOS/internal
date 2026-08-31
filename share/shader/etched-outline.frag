// Name: Etched Outline
// Author: MustardOS
// Version: 3

#pragma parameter gain "Edge Gain" 1.00 0.10 4.00 0.10

uniform float gain;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

void main() {
    const vec3 LUMA = vec3(0.299, 0.587, 0.114);
    vec2 px = 1.0 / native_res();

    float a = dot(texture2D(u_tex, clamp(v_uv + vec2(-px.x, -px.y), 0.0, 1.0)).rgb, LUMA);
    float b = dot(texture2D(u_tex, clamp(v_uv + vec2( px.x, -px.y), 0.0, 1.0)).rgb, LUMA);
    float c = dot(texture2D(u_tex, clamp(v_uv + vec2(-px.x,  px.y), 0.0, 1.0)).rgb, LUMA);
    float d = dot(texture2D(u_tex, clamp(v_uv + vec2( px.x,  px.y), 0.0, 1.0)).rgb, LUMA);

    gl_FragColor = vec4(vec3((abs(a - d) + abs(b - c)) * gain), 1.0);
}
