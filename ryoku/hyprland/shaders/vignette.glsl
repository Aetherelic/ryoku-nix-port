#version 300 es
precision highp float;

// The plate edge: a soft falloff to the corners, so the screen reads as a page
// lit from the middle. The one print filter that leaves colour alone.

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float radius = 0.85;
const float softness = 0.6;
const float strength = 0.55;   // a vignette you can name is too strong

void main() {
    vec2 res = vec2(textureSize(tex, 0));
    vec3 src = texture(tex, clamp(v_texcoord, 0.0, 1.0)).rgb;

    // aspect-corrected, else a 16:9 panel gets an oval
    vec2 p = (v_texcoord - 0.5) * 2.0;
    p.x *= res.x / max(res.y, 1.0);
    float d = length(p) / length(vec2(res.x / max(res.y, 1.0), 1.0));

    fragColor = vec4(src * (1.0 - strength * smoothstep(radius - softness, radius + softness, d)), 1.0);
}
