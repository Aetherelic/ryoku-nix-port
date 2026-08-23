#version 440

// The qsbar gap animation (ParticleStream drift modes 1-6) as a fragment shader
// instead of a threaded Canvas. The Canvas ran this exact procedural math on the
// CPU and rasterised dozens of fills per frame (~25% of a core, and far more GPU
// on integrated panels); here the GPU evaluates it per pixel from a single `time`
// uniform, so the bar animates smoothly at ~0 CPU on every power profile. One
// ShaderEffect instance fills one bar gap; `gapX` places each pixel on the shared
// global grid (mode 1 is a continuous marquee across gaps) and `gapIndex` is the
// gap number `g` that staggers the per-gap cycles. Output is premultiplied alpha.
//
// The stateful modes -- 7 (reactor, event-pulse queues) and 8 (quotes, a
// dot-matrix text buffer) -- keep cross-frame state and stay on the Canvas.

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;      // seconds since the clock started (now = time*1000 ms)
    float aud;       // 0..1 audio energy (mode 1: faster, brighter dots)
    float gapX;      // this gap's left edge in global bar px (shared grid)
    float gapW;      // gap width  in px
    float gapH;      // gap height in px
    float gapIndex;  // gap number g -> per-gap cycle stagger
    float mode;      // 1..6 drift mode
    vec4  seal;      // accent colour (rgb used)
};

const float PI = 3.14159265;

float hash(float n) { float s = sin(n * 127.1) * 43758.5453; return s - floor(s); }

// premultiplied "over": composite colour c at coverage a onto acc.
void over(inout vec4 acc, vec3 c, float a) {
    a = clamp(a, 0.0, 1.0);
    acc = vec4(c * a, a) + acc * (1.0 - a);
}
// hard disc (Canvas arc+fill), feathered ~1px for AA.
float disc(vec2 p, float r) { return 1.0 - smoothstep(r - 1.0, r, length(p)); }
// soft radial glow (Canvas createRadialGradient, linear stop): 1 at centre -> 0 at r.
float glow(vec2 p, float r) { return max(0.0, 1.0 - length(p) / max(r, 0.001)); }
// stroke coverage of a line of width w at signed distance d.
float strokeA(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d); }
// distance from p to segment a-b.
float segd(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

// ---- mode 1: STREAM -- dots riding a glowing rail (global marquee) ----------
void mSTREAM(inout vec4 acc, float px, float dy, float now, vec3 S, vec3 W) {
    over(acc, S, 0.14 * (1.0 - smoothstep(0.0, 8.0, abs(dy))));   // outer glow aura
    over(acc, S, 0.55 * strokeA(abs(dy), 1.5));                   // rail
    over(acc, W, 0.28 * strokeA(abs(dy), 0.75));                  // white core
    // slow layer (sparse, big, faint) under the fast layer.
    {
        float sp = 110.0, off = mod(now / 1000.0 * 38.0, sp);
        float k  = floor((px - off) / sp + 0.5);
        vec2  p  = vec2(px - (off + k * sp), dy);
        over(acc, S, 0.11 * disc(p, 8.5));
        over(acc, W, 0.50 * disc(p, 2.3));
    }
    // fast layer (dense, small, bright); every 5th dot pulses; audio speeds it up.
    {
        float sp = 65.0, off = mod(now / 1000.0 * (70.0 + aud * 160.0), sp);
        float k  = floor((px - off) / sp + 0.5);
        vec2  p  = vec2(px - (off + k * sp), dy);
        bool  pulse = mod(k, 5.0) < 0.5;
        float ph = 0.5 + 0.5 * sin(now / 700.0 + k * 2.4);
        over(acc, S, (pulse ? min(1.0, 0.28 + ph * 0.18 + aud * 0.4) : 0.30)
                     * disc(p, pulse ? (4.0 + ph * 1.5 + aud * 4.0) : 4.5));
        over(acc, W, (pulse ? 0.95 : 0.90) * disc(p, pulse ? (1.6 + ph * 0.4) : 1.6));
    }
}

// ---- mode 2: SURGE -- pulses race inward from both edges, meet, flash -------
void mSURGE(inout vec4 acc, float px, vec2 P, float cy, float x1, float x2,
            float gw, float now, float g, vec3 S, vec3 W) {
    float T = 3900.0;
    float p = fract(now / T + g * 0.20);
    float env = min(1.0, p / 0.12);
    float mid = (x1 + x2) * 0.5, reach = gw * 0.5;
    float xL = x1 + p * reach, xR = x2 - p * reach;
    float dcy = abs(P.y - cy);

    over(acc, S, 0.16 * strokeA(dcy, 1.0));                       // faint rail
    // current traces: faint at the origin edge -> bright at the head.
    if (px >= x1 && px <= xL)
        over(acc, S, 0.5 * env * clamp((px - x1) / max(xL - x1, 1e-3), 0.0, 1.0) * strokeA(dcy, 1.6));
    if (px >= xR && px <= x2)
        over(acc, S, 0.5 * env * clamp((x2 - px) / max(x2 - xR, 1e-3), 0.0, 1.0) * strokeA(dcy, 1.6));
    // bright heads (seal glow + white core).
    over(acc, S, 0.45 * env * glow(P - vec2(xL, cy), 4.0));
    over(acc, S, 0.45 * env * glow(P - vec2(xR, cy), 4.0));
    over(acc, W, 0.95 * env * disc(P - vec2(xL, cy), 1.7));
    over(acc, W, 0.95 * env * disc(P - vec2(xR, cy), 1.7));
    // soft flash where the two pulses meet.
    if (p > 0.78) {
        float fl = (p - 0.78) / 0.22;
        over(acc, W, 0.50 * (1.0 - fl) * disc(P - vec2(mid, cy), 2.0 + fl * 6.0));
        over(acc, S, 0.30 * (1.0 - fl) * glow(P - vec2(mid, cy), 4.0 + fl * 10.0));
    }
}

// jagged bolt polyline (Canvas drawStrike): hot channel + fading ion trail.
void drawStrike(inout vec4 acc, vec2 P, float x1, float gw, float cy,
                float boltAmp, float segsF, float laneSeed, float hot, float trail,
                vec3 S, vec3 W) {
    if (hot <= 0.01 && trail <= 0.01) return;
    float lean = (hash(laneSeed + 700.0) - 0.5) * 2.0 * boltAmp * 0.55;
    float mind = 1e9;
    vec2  prev = vec2(x1, cy);
    for (int i = 1; i <= 16; i++) {
        if (float(i) > segsF) break;
        float t  = float(i) / segsF;
        float bx = x1 + t * gw;
        float by = (float(i) >= segsF - 0.5) ? cy
                 : cy + (hash(laneSeed + float(i)) - 0.5) * 2.0 * boltAmp + sin(t * PI) * lean;
        mind = min(mind, segd(P, prev, vec2(bx, by)));
        prev = vec2(bx, by);
    }
    over(acc, S, 0.18 * trail * strokeA(mind, 4.8));
    over(acc, W, 0.08 * trail * strokeA(mind, 1.8));
    over(acc, S, 0.40 * hot   * strokeA(mind, 3.2));
    over(acc, W, 0.92 * hot   * strokeA(mind, 1.15));
}

float strikeEnv(float t, float start, float end, float power) {
    if (t < start || t > end) return 0.0;
    float u = (t - start) / (end - start);
    return power * pow(1.0 - u, 2.35);
}
float trailEnv(float t, float start, float end, float power) {
    if (t < start || t > end) return 0.0;
    float u = (t - start) / (end - start);
    return power * pow(1.0 - u, 1.55);
}

// ---- mode 3: BOLT -- charged wave field, then a discharge arc ---------------
void mBOLT(inout vec4 acc, vec2 P, float px, float cy, float x1, float x2,
           float gw, float gapH, float now, float g, vec3 S, vec3 W) {
    float Tb = 3800.0;
    float local = now / Tb + g * 0.37;
    float ph   = fract(local);
    float seed = floor(local) * 131.7 + g * 53.3;
    bool  charging = ph < 0.82;
    float charge = pow(min(1.0, ph / 0.82), 1.6);
    float dw     = charging ? 0.0 : (ph - 0.82) / 0.18;
    float waveI  = charging ? charge : (1.0 - dw);

    // charged field: two overlapping wave lines that swell as they charge.
    float baseAmp = min(gapH * 0.30, 6.0);
    float amp     = (0.22 + 0.78 * waveI) * baseAmp;
    float waveT   = now / 1300.0;
    float k0 = 0.055, s0 = -3.0, p0 = 0.0, w0 = 1.00;
    float k1 = 0.072, s1 =  3.6, p1 = 2.4, w1 = 0.78;
    float y0 = cy + amp * w0 * sin(px * k0 + waveT * s0 + p0);
    float y1 = cy + amp * w1 * sin(px * k1 + waveT * s1 + p1);
    over(acc, S, (0.05 + waveI * 0.16) * w0 * strokeA(abs(P.y - y0), 2.6));
    over(acc, S, (0.22 + waveI * 0.55) * w0 * strokeA(abs(P.y - y0), 1.0));
    over(acc, S, (0.05 + waveI * 0.16) * w1 * strokeA(abs(P.y - y1), 2.6));
    over(acc, S, (0.22 + waveI * 0.55) * w1 * strokeA(abs(P.y - y1), 1.0));

    // discharge: the stored charge releases as a bright arc + flash.
    if (!charging) {
        float segsF   = clamp(floor(gw / 26.0 + 0.5), 4.0, 14.0);
        float boltAmp = min(gapH * 0.26, 4.6);
        float aStart = 0.015 + hash(seed + 211.0) * 0.085;
        float aEnd   = aStart + 0.24 + hash(seed + 212.0) * 0.10;
        float bStart = aStart + 0.21 + hash(seed + 213.0) * 0.18;
        float bEnd   = min(0.98, bStart + 0.24 + hash(seed + 214.0) * 0.12);
        float strikeA_ = strikeEnv(dw, aStart, aEnd, 0.86 + hash(seed + 215.0) * 0.20);
        float strikeB_ = strikeEnv(dw, bStart, bEnd, 0.72 + hash(seed + 216.0) * 0.26);
        float trailA_  = trailEnv(dw, aStart + 0.02, min(0.96, aEnd + 0.38 + hash(seed + 217.0) * 0.16), 0.54 + hash(seed + 218.0) * 0.18);
        float trailB_  = trailEnv(dw, bStart + 0.02, min(0.99, bEnd + 0.28 + hash(seed + 219.0) * 0.14), 0.42 + hash(seed + 220.0) * 0.16);
        float flashA = max(strikeA_, strikeB_);
        float fla = pow(flashA, 1.15) + 0.10 * max(trailA_, trailB_);
        if (fla > 0.0) over(acc, S, 0.24 * fla * max(0.0, 1.0 - abs(P.y - cy) / 9.0));  // release flash band
        drawStrike(acc, P, x1, gw, cy, boltAmp, segsF, seed + 17.0 + hash(seed + 221.0) * 23.0, strikeA_, trailA_, S, W);
        drawStrike(acc, P, x1, gw, cy, boltAmp, segsF, seed + 91.0 + hash(seed + 222.0) * 29.0, strikeB_, trailB_, S, W);
    }
}

// ---- mode 4: SPARK GAP -- edge micro-sparks + a full breakdown arc ----------
void mSPARK(inout vec4 acc, vec2 P, float cy, float x1, float x2, float gw,
            float gapH, float now, float g, vec3 S, vec3 W) {
    float aS = min(gapH * 0.30, 5.5);
    // micro sparks: short arcs at random edge spots (deterministic per slot).
    float slot = floor(now / 300.0);
    float sIn  = fract(now / 300.0);
    for (int sk = 0; sk < 2; sk++) {
        float sps = slot * 77.7 + g * 13.3 + float(sk) * 311.1;
        if (hash(sps) > 0.32) continue;
        float life = 1.0 - sIn;
        if (life <= 0.0) continue;
        bool  left = hash(sps + 1.0) < 0.5;
        float ex0  = left ? x1 : x2;
        float dir  = left ? 1.0 : -1.0;
        float ey0  = cy + (hash(sps + 2.0) - 0.5) * gapH * 0.45;
        float sln  = 4.0 + hash(sps + 3.0) * 6.0;
        float mind = 1e9;
        vec2  prev = vec2(ex0, ey0);
        for (int sj = 1; sj <= 3; sj++) {
            vec2 v = vec2(ex0 + dir * sln * (float(sj) / 3.0), ey0 + (hash(sps + 4.0 + float(sj)) - 0.5) * 4.0);
            mind = min(mind, segd(P, prev, v));
            prev = v;
        }
        float fl4 = 0.6 + 0.4 * sin(now / 23.0 + sps);
        over(acc, S, 0.30 * life * fl4 * strokeA(mind, 1.6));
        over(acc, W, 0.75 * life * fl4 * strokeA(mind, 0.7));
        over(acc, W, 0.55 * life * disc(P - vec2(ex0, ey0), 0.9));
    }
    // breakdown: one full arc bridges the gap, then darkness.
    float T4  = 4000.0;
    float lo4 = now / T4 + g * 0.37;
    float ph4 = fract(lo4);
    float sd4 = floor(lo4) * 131.7 + g * 53.3;
    float st4 = 0.10 + hash(sd4 + 99.0) * 0.75;
    float s4  = (ph4 - st4) * T4;
    if (s4 >= 0.0 && s4 < 340.0) {
        float b4 = (s4 < 90.0) ? 1.0 : (s4 < 150.0) ? 0.25 : (s4 < 230.0) ? 0.7 : 0.7 * (1.0 - (s4 - 230.0) / 110.0);
        b4 *= 0.82 + 0.18 * sin(now / 21.0);
        float segsF = clamp(floor(gw / 22.0 + 0.5), 4.0, 16.0);
        float mind = 1e9;
        vec2  prev = vec2(x1, cy);
        for (int i = 1; i <= 16; i++) {
            if (float(i) > segsF) break;
            float bx = x1 + (float(i) / segsF) * gw;
            float by = (float(i) >= segsF - 0.5) ? cy : cy + (hash(sd4 + float(i)) - 0.5) * 2.0 * aS;
            mind = min(mind, segd(P, prev, vec2(bx, by)));
            prev = vec2(bx, by);
        }
        over(acc, S, 0.42 * b4 * strokeA(mind, 3.4));
        over(acc, W, 0.95 * b4 * strokeA(mind, 1.2));
        float ebr = 6.0 + b4 * 3.0;                                  // electrode blooms
        over(acc, S, 0.50 * b4 * glow(P - vec2(x1, cy), ebr));
        over(acc, S, 0.50 * b4 * glow(P - vec2(x2, cy), ebr));
    }
}

// ---- mode 5: TRANSFER -- a droplet grows, glides across, is absorbed --------
void mTRANSFER(inout vec4 acc, vec2 P, float px, float cy, float x1, float x2,
               float gw, float now, float g, vec3 S, vec3 W) {
    float T5  = 3200.0;
    float lo5 = now / T5 + g * 0.41;
    float ph5 = fract(lo5);
    float sd5 = floor(lo5) * 131.7 + g * 53.3;
    float st5 = hash(sd5 + 9.0) * 0.22;
    float p5  = (ph5 - st5) / 0.74;
    if (p5 < 0.0 || p5 > 1.0) return;
    float R5 = 2.4, dx5, sc5 = 1.0; bool absorbed = false;
    if (p5 < 0.40) { dx5 = x1; sc5 = p5 / 0.40; }
    else if (p5 < 0.85) { float u = (p5 - 0.40) / 0.45; u = u * u * (3.0 - 2.0 * u); dx5 = x1 + u * gw; }
    else { absorbed = true; dx5 = -1.0; }

    if (!absorbed) {
        if (p5 >= 0.40 && dx5 > x1 + 4.0 && px >= dx5 - 14.0 && px <= dx5)  // gliding trail
            over(acc, S, 0.35 * clamp((px - (dx5 - 14.0)) / 14.0, 0.0, 1.0) * strokeA(abs(P.y - cy), 1.4));
        float br5 = 0.92 + 0.08 * sin(now / 130.0);
        over(acc, S, 0.55 * sc5 * glow(P - vec2(dx5, cy), R5 * 2.6 * sc5 * br5));
        over(acc, W, 0.92 * sc5 * disc(P - vec2(dx5, cy), R5 * 0.7 * sc5));
    } else {
        float fb5 = 1.0 - (p5 - 0.85) / 0.15;                          // absorbed flash
        over(acc, S, 0.60 * fb5 * glow(P - vec2(x2, cy), 8.0));
        over(acc, W, 0.90 * fb5 * disc(P - vec2(x2, cy), 1.2 * fb5));
    }
}

// ---- mode 6: COLLIDER -- two particles smash mid-gap, debris flies ----------
void mCOLLIDER(inout vec4 acc, vec2 P, float cy, float x1, float x2, float gw,
               float now, float g, vec3 S, vec3 W) {
    float T6  = 3800.0;
    float lo6 = now / T6 + g * 0.31;
    float ph6 = fract(lo6);
    float sd6 = floor(lo6) * 131.7 + g * 53.3;
    float st6 = hash(sd6 + 9.0) * 0.5;
    float s6  = (ph6 - st6) * T6;
    if (s6 < 0.0 || s6 >= 1180.0) return;
    float mid6 = (x1 + x2) * 0.5, IN6 = 580.0;
    if (s6 < IN6) {
        float u6 = s6 / IN6; u6 = u6 * u6;
        for (int c6 = 0; c6 < 2; c6++) {
            float hx6 = (c6 == 0) ? (x1 + u6 * (mid6 - x1)) : (x2 - u6 * (x2 - mid6));
            float bk6 = ((c6 == 0) ? -1.0 : 1.0) * (8.0 + u6 * 14.0);
            float lo = min(hx6, hx6 + bk6), hi = max(hx6, hx6 + bk6);
            if (P.x >= lo && P.x <= hi)                               // motion-blur trail
                over(acc, S, 0.45 * clamp(1.0 - abs(P.x - hx6) / max(abs(bk6), 1e-3), 0.0, 1.0) * strokeA(abs(P.y - cy), 1.6));
            over(acc, S, 0.50 * glow(P - vec2(hx6, cy), 4.5));
            over(acc, W, 0.95 * disc(P - vec2(hx6, cy), 1.5));
        }
    } else {
        float t6  = (s6 - IN6) / 600.0;
        float fl6 = pow(1.0 - t6, 1.6);
        float fr6 = 5.0 + t6 * 9.0;
        over(acc, S, 0.60 * fl6 * glow(P - vec2(mid6, cy), fr6));
        if (t6 < 0.25) over(acc, W, 0.95 * (1.0 - t6 / 0.25) * disc(P - vec2(mid6, cy), 1.8));
        float ez6 = 1.0 - pow(1.0 - t6, 2.0);
        for (int k6 = 0; k6 < 5; k6++) {                             // debris shards
            float an6 = (hash(sd6 + 30.0 + float(k6)) - 0.5) * 2.4 + ((k6 - (k6 / 2) * 2 == 0) ? 0.0 : PI);
            float dd6 = (8.0 + hash(sd6 + 40.0 + float(k6)) * 14.0) * ez6;
            vec2  a = vec2(mid6 + cos(an6) * dd6, cy + sin(an6) * dd6 * 0.55);
            vec2  b = a + vec2(cos(an6) * 3.5, sin(an6) * 3.5 * 0.55);
            over(acc, W, 0.75 * fl6 * strokeA(segd(P, a, b), 0.8));
        }
    }
}

void main() {
    float px  = gapX + qt_TexCoord0.x * gapW;
    float py  = qt_TexCoord0.y * gapH;
    float cy  = gapH * 0.5;
    float dy  = py - cy;
    float now = time * 1000.0;
    float g   = gapIndex;
    float x1  = gapX, x2 = gapX + gapW, gw = gapW;
    vec2  P   = vec2(px, py);
    vec3  S   = seal.rgb, W = vec3(1.0);

    vec4 acc = vec4(0.0);
    if      (mode < 1.5) mSTREAM(acc, px, dy, now, S, W);
    else if (mode < 2.5) mSURGE(acc, px, P, cy, x1, x2, gw, now, g, S, W);
    else if (mode < 3.5) mBOLT(acc, P, px, cy, x1, x2, gw, gapH, now, g, S, W);
    else if (mode < 4.5) mSPARK(acc, P, cy, x1, x2, gw, gapH, now, g, S, W);
    else if (mode < 5.5) mTRANSFER(acc, P, px, cy, x1, x2, gw, now, g, S, W);
    else                 mCOLLIDER(acc, P, cy, x1, x2, gw, now, g, S, W);

    fragColor = acc * qt_Opacity;
}
