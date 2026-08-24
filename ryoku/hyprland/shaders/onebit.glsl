#version 300 es
precision highp float;

// One bit: paper or ink, nothing between. Uses the same 4x4 threshold table as
// the shell's image dither (ryoku/ui/shaders/dither.frag) so a dithered image
// and a dithered desktop agree.

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const vec3 ink = vec3(0.804, 0.769, 0.729);   // #cdc4ba

float bayer4(vec2 pos) {
    vec2 f = floor(mod(pos, 4.0));
    float i = f.y * 4.0 + f.x;
    float t = 5.5 / 16.0;
    if (i < 0.5) t = 0.5 / 16.0; else if (i < 1.5) t = 8.5 / 16.0;
    else if (i < 2.5) t = 2.5 / 16.0; else if (i < 3.5) t = 10.5 / 16.0;
    else if (i < 4.5) t = 12.5 / 16.0; else if (i < 5.5) t = 4.5 / 16.0;
    else if (i < 6.5) t = 14.5 / 16.0; else if (i < 7.5) t = 6.5 / 16.0;
    else if (i < 8.5) t = 3.5 / 16.0; else if (i < 9.5) t = 11.5 / 16.0;
    else if (i < 10.5) t = 1.5 / 16.0; else if (i < 11.5) t = 9.5 / 16.0;
    else if (i < 12.5) t = 15.5 / 16.0; else if (i < 13.5) t = 7.5 / 16.0;
    else if (i < 14.5) t = 13.5 / 16.0;
    return t;
}

void main() {
    vec2 res = vec2(textureSize(tex, 0));
    vec3 src = texture(tex, clamp(v_texcoord, 0.0, 1.0)).rgb;
    // lifted before the compare: a linear threshold crushes the midtones that
    // carry text on dark app chrome
    float v = pow(dot(src, vec3(0.2126, 0.7152, 0.0722)), 0.75);
    fragColor = vec4(step(bayer4(v_texcoord * res), v) * ink, 1.0);
}
