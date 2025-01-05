#version 130

/*
    Authentic GBC by fishku
    Copyright (C) 2024
    Public domain license (CC0)

    Attempts to render GBC subpixels authentically.

    Reference photos:
    - https://gbcc.dev/technology/subpixels.jpg

    Inspired by:
    -
   https://www.reddit.com/r/AnaloguePocket/comments/1azaxgd/ive_made_some_improvements_to_my_analogue_pocket/

    Changelog:
    v1.1: Use OriginalSize instead of SourceSize to better work with combined presets.
    v1.0: Initial release, ported from Slang.
*/

// clang-format off
#pragma parameter AUTH_GBC_SETTINGS "=== Authentic GBC v1.1 settings ===" 0.0 0.0 1.0 1.0
#pragma parameter AUTH_GBC_BRIG "Overbrighten" 0.15 -0.1 1.0 0.05
// clang-format on

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION vec2 OrigInputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform COMPAT_PRECISION vec2 OutputSize;

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;

COMPAT_VARYING vec4 px_rect;
COMPAT_VARYING vec2 tx_to_uv;
COMPAT_VARYING vec2 tx_coord;
COMPAT_VARYING vec2 tx_to_px;
COMPAT_VARYING vec2 subpx_size;
COMPAT_VARYING vec2 notch_size;
COMPAT_VARYING float subpx_orig_y;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float AUTH_GBC_BRIG;
#else
#define AUTH_GBC_BRIG 0.0
#endif

// As determined by counting pixels on a photo.
const vec2 subpx_ratio = vec2(0.296, 0.910);
const vec2 notch_ratio = vec2(0.115, 0.166);

void main() {
    gl_Position = MVPMatrix * VertexCoord;

    // Given coordinates in source texel coord. system, multiply by this to get UV in
    // [0, 1] to sample from source.
    tx_to_uv = 1.0 / OrigInputSize * InputSize / TextureSize;

    // Fragment coordinates in output pixel system in [0, output size]
    vec2 px_coord = TexCoord.xy * OutputSize * TextureSize / InputSize;
    // Upper left and bottom right corner of square surrounding the output fragment
    px_rect = vec4(px_coord - 0.5, px_coord + 0.5);
    // Texel coordinates in source texel system in [0, original input size]
    tx_coord = TexCoord.xy * OrigInputSize * TextureSize / InputSize;
    // Size of one output pixel in source texel coordinates (inverse of texel size in pixels).
    // Multiply a texel coordinate by this to get pixel coordinates
    tx_to_px = OutputSize / OrigInputSize;

    // Precompute some sizes that are common for all sampled subpixels.
    // Size in pixels of a single R/G/B subpixel
    subpx_size = tx_to_px * mix(subpx_ratio, vec2(2.0 / 3.0, 1.0), AUTH_GBC_BRIG);
    // Size in pixels of the "notch" present in the corner of each subpixel
    notch_size = tx_to_px * mix(notch_ratio, vec2(0.0), AUTH_GBC_BRIG);
    // Y coordinate in output pixel system of the origin of the subpixel, centered vertically
    subpx_orig_y = (tx_to_px.y - subpx_size.y) * 0.5;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out COMPAT_PRECISION vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

uniform COMPAT_PRECISION vec2 TextureSize;

uniform sampler2D Texture;

COMPAT_VARYING vec4 px_rect;
COMPAT_VARYING vec2 tx_to_uv;
COMPAT_VARYING vec2 tx_coord;
COMPAT_VARYING vec2 tx_to_px;
COMPAT_VARYING vec2 subpx_size;
COMPAT_VARYING vec2 notch_size;
COMPAT_VARYING float subpx_orig_y;

float rect_coverage(vec4 rect) {
    vec2 bl = max(rect.xy, px_rect.xy);
    vec2 tr = min(rect.zw, px_rect.zw);
    vec2 coverage = max(tr - bl, 0.0);
    return coverage.x * coverage.y;
}

float subpx_coverage(vec2 subpx_orig) {
    return rect_coverage(vec4(subpx_orig, subpx_orig + subpx_size)) -
           rect_coverage(vec4(subpx_orig.x, subpx_orig.y + subpx_size.y - notch_size.y,
                              subpx_orig.x + notch_size.x, subpx_orig.y + subpx_size.y));
}

vec3 pixel_color(vec2 px_orig) {
    return vec3(
        subpx_coverage(px_orig + vec2(tx_to_px.x / 6.0 - subpx_size.x * 0.5, subpx_orig_y)),
        subpx_coverage(px_orig + vec2(tx_to_px.x / 2.0 - subpx_size.x * 0.5, subpx_orig_y)),
        subpx_coverage(px_orig + vec2(5.0 * tx_to_px.x / 6.0 - subpx_size.x * 0.5, subpx_orig_y)));
}

void main() {
    // Figure out 4 nearest texels in source texture.
    // All coordinates in source texel coord. system
    vec2 tx_coord_i;
    vec2 tx_coord_f = modf(tx_coord, tx_coord_i);
    vec2 tx_coord_off = step(vec2(0.5), tx_coord_f) * 2.0 - 1.0;
    vec2 tx_origins[4] = vec2[](tx_coord_i, tx_coord_i + vec2(tx_coord_off.x, 0.0),
                                tx_coord_i + vec2(0.0, tx_coord_off.y), tx_coord_i + tx_coord_off);

    // Sample.
    // Apply square for fast "gamma correction".
    vec3 samples[4] = vec3[](texture(Texture, (tx_origins[0] + 0.5) * tx_to_uv).rgb,
                             texture(Texture, (tx_origins[1] + 0.5) * tx_to_uv).rgb,
                             texture(Texture, (tx_origins[2] + 0.5) * tx_to_uv).rgb,
                             texture(Texture, (tx_origins[3] + 0.5) * tx_to_uv).rgb);
    samples[0] *= samples[0];
    samples[1] *= samples[1];
    samples[2] *= samples[2];
    samples[3] *= samples[3];

    // Apply shader.
    vec3 res = samples[0] * pixel_color(tx_origins[0] * tx_to_px) +
               samples[1] * pixel_color(tx_origins[1] * tx_to_px) +
               samples[2] * pixel_color(tx_origins[2] * tx_to_px) +
               samples[3] * pixel_color(tx_origins[3] * tx_to_px);

    // Apply sqrt for fast "gamma correction".
    FragColor = vec4(sqrt(res), 1.0);
}

#endif
