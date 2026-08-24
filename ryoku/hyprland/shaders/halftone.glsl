#version 300 es
precision highp float;

// The print screen: the whole desktop, apps included, resolved to bone ink dots
// on black paper by the compositor rather than by each surface.

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float cell = 4.0;      // dot pitch in px; 3-6 reads as newsprint
const float levels = 5.0;
const vec3 ink = vec3(0.804, 0.769, 0.729);   // #cdc4ba
const vec3 paper = vec3(0.0);
const float softness = 1.2;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Ordered 4x4 Bayer as a signed threshold, so five ink steps read as a ramp
// instead of banding.
float bayer(vec2 p) {
    int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
    float m[16] = float[16](
         0.0,  8.0,  2.0, 10.0,
        12.0,  4.0, 14.0,  6.0,
         3.0, 11.0,  1.0,  9.0,
        15.0,  7.0, 13.0,  5.0);
    return m[i] / 16.0 - 0.5;
}

void main() {
    vec2 res = vec2(textureSize(tex, 0));
    vec2 px = v_texcoord * res;
    vec3 src = texture(tex, clamp(v_texcoord, 0.0, 1.0)).rgb;

    float v = luma(src);
    v = clamp(floor((v + bayer(px) / levels) * levels) / (levels - 1.0), 0.0, 1.0);

    // dot area carries the tone (sqrt: the eye reads area, not radius) and the
    // edge comes off the derivative, so the pitch holds at any resolution
    vec2 grid = fract(px / cell) - 0.5;
    float r = sqrt(v) * 0.5;
    float d = length(grid);
    float w = fwidth(d) * softness;

    fragColor = vec4(mix(paper, ink, 1.0 - smoothstep(r - w, r + w, d)), 1.0);
}
