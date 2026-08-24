#version 300 es
precision highp float;

// Every window on the desktop's ink ramp: tone kept, hue dropped, remapped from
// black paper up to bone rather than to white, so an app stops glowing brighter
// than the shell framing it.

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const vec3 ink = vec3(0.804, 0.769, 0.729);   // #cdc4ba
const float lift = 0.85;   // <1 opens the shadows; text on dark chrome needs it

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void main() {
    vec3 src = texture(tex, clamp(v_texcoord, 0.0, 1.0)).rgb;
    fragColor = vec4(ink * pow(clamp(luma(src), 0.0, 1.0), lift), 1.0);
}
