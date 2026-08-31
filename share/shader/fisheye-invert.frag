// Name: Fish Eye - Inverted
// Author: MustardOS
// Version: 3

#pragma parameter strength "Warp Strength" 0.45 0.00 1.00 0.01
#pragma parameter falloff "Corner Falloff" 0.50 0.00 1.50 0.05

uniform float strength;
uniform float falloff;

void main() {
    vec2 uv = v_uv * 2.0 - 1.0;
    vec2 asuv = uv * vec2(u_resolution.x / u_resolution.y, 1.0);
    float r = length(asuv);

    float warp = 1.0 + strength * (r * r);
    vec2 warped = uv * warp * 0.5 + 0.5;

    if (warped.x <= 0.0 || warped.x >= 1.0 || warped.y <= 0.0 || warped.y >= 1.0) {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec3 col = texture2D(u_tex, warped).rgb;
    col *= clamp(1.0 - r * r * falloff, 0.0, 1.0);

    gl_FragColor = vec4(col, 1.0);
}
