// floor_echo.glsl — the floor as a dark glaze reflecting the mural (FloorEcho.pde)
// Every point of the floor reflects the part of the wall in front of it (a point at distance d
// from a wall reflects that wall at height d), fading towards the centre, gently warped.
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;    // (dummy: gives the coordinates)
uniform sampler2D w1;         // WALL 1 (x = 0, its u runs from y = D down to 0)
uniform sampler2D w2;         // WALL 2 (y = 0, u = x)
uniform sampler2D w4;         // WALL 4 (y = D, u runs from x = W down to 0)
uniform vec3  room;           // W, D, wall height
uniform float flipY, flipTex;
uniform float mode;           // 1 soft · 2 fragmented · 3 almost black
uniform float strength;       // how bright the reflections are
uniform float reach;          // how far into the room they reach (room units)
uniform float warp;           // how much the slow warp bends them
uniform float time;
uniform float cell;           // mode 2: size of the reflecting shards
uniform float dimK;           // 0 … 1: the floor darkens (a verse is shown)
uniform float stretch;        // the reflections reach this many times the wall height into the room
uniform float blur;           // A, C: softness (texture units)

uniform vec4  openings[2];    // x, y, half-width, half-height of a window opening in the reflection
uniform float openK[2];       // how open (0 … 1)
uniform vec3  rimCol;
uniform float revealStyle;   // 1: the verse's zone only calms and dims (no window); the word's is a condensation of warm light
uniform float calmDim;       // how much the verse's zone dims
uniform float wordGlow;      // how bright the word's condensation of light is
uniform vec3  wordPts[10];   // the drifting words: x, y, strength — they stir the glaze under them
uniform float nWordPts;
uniform float wordRipple;
uniform sampler2D wordsTex;   // the visitors' words (A coverage, R freshly written)
uniform float wordsOn;
uniform vec3  amber, bright;
uniform vec3  poemCol;       // the poem's own words: paler (G = 0 in wordsTex)
uniform float wordLight;
uniform float wordBase;
uniform float colSat;        // the reflection's colours: saturation (1 = as the mural)
uniform float colContrast;   // …contrast: the haze between them darker, the colours themselves kept      // the words' own light, even where the floor is dark
uniform float nWaves;
uniform vec4  waves[4];       // x, y, radius, intensity
uniform vec3  waveCols[4];
uniform float waveWidth;

varying vec4 vertTexCoord;

vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }

// A tap: colour already weighted by coverage (the wall images are cleared to transparent black
// and blurred, so their rgb is premultiplied) and the coverage itself
vec4 tapA(sampler2D t, vec2 tc) { return texture2D(t, clamp(tc, vec2(0.001), vec2(0.999))); }

// The wall reflected at distance d: never a hard edge — it fades with height, at the ends of the
// wall and where the mural isn't there yet; gaps in the mural are filled by their surroundings
vec3 sampleWall(sampler2D t, float u, float len, float d, float stretch, float blur) {
  d = max(d, 0.0);
  float h = d / stretch;                            // the wall at height h above the floor, stretched across the room
  float x = clamp(h / room.z, 0.0, 1.0);
  float fadeH = pow(1.0 - x, 1.7) * (1.0 - 0.35 * x); // a long tail that eases into black across the floor: no visible end
  float fadeU = smoothstep(-0.06 * len, 0.04 * len, u) * (1.0 - smoothstep(0.96 * len, 1.06 * len, u));
  if (fadeH * fadeU <= 0.0) return vec3(0.0);
  float tv = clamp((room.z - h) / room.z, 0.0, 1.0);
  vec2 tc = vec2(u / len, flipTex > 0.5 ? 1.0 - tv : tv);
  vec4 acc;
  if (blur <= 0.0) acc = tapA(t, tc);
  else {
    vec2 b = vec2(blur, blur * (1.0 + 4.0 * x));    // sharp at the foot of the wall, softer as it reaches into the room
    acc = tapA(t, tc) * 0.16;
    for (int i = 0; i < 12; i++) {                  // two rings of taps
      float a = 6.2831853 * float(i) / 12.0 + 0.26;
      vec2 o = vec2(cos(a), sin(a)) * b;
      acc += tapA(t, tc + o * 0.5) * 0.04 + tapA(t, tc + o) * 0.03;
    }
  }
  vec3 col = acc.rgb / max(acc.a, 0.02);            // the mural's colour, gaps filled
  float cov = smoothstep(0.0, 0.85, acc.a);         // and how much mural there is around (soft)
  return min(col, vec3(1.0)) * cov * fadeH * fadeU;
}

void main() {
  vec2 st = vertTexCoord.st;
  vec2 uv = vec2(st.x, flipY > 0.5 ? 1.0 - st.y : st.y);
  vec2 p = uv * room.xy;
  float W = room.x, D = room.y;

  // the slow organic warp of the glaze
  float tt = time * 0.05;
  vec2 wv = vec2(sin(p.y * 0.0011 + tt * 1.3) + sin(p.x * 0.0007 - tt * 0.9 + p.y * 0.0004),
                 sin(p.x * 0.0013 - tt * 1.1) + sin(p.y * 0.0006 + tt * 0.7 - p.x * 0.0005)) * warp;

  // the words' waves: a ring of colour that also bends the reflections as it passes
  vec3 waveLight = vec3(0.0);
  float waveBoost = 0.0;
  for (int i = 0; i < 4; i++) {
    if (float(i) >= nWaves) break;
    vec4 Wv = waves[i];
    vec2 dv = p - Wv.xy;
    float dist = length(dv);
    float x = (dist - Wv.z) / waveWidth;
    float band = exp(-x * x);
    float inside = smoothstep(Wv.z, Wv.z - waveWidth * 3.0, dist) * 0.25;
    wv += normalize(dv + 0.001) * sin(x * 2.4) * band * Wv.w * 70.0;
    waveLight += waveCols[i] * Wv.w * (band + inside);
    waveBoost += Wv.w * band;
  }

  // the openings (old style) — or, revealStyle 1: the verse's zone calms (its warp settles) and dims
  // softly over a wide area, no edge at all; the word's zone gathers a little warm light
  float hole = 0.0, rim = 0.0, glow = 0.0;
  for (int i = 0; i < 2; i++) {
    if (openK[i] <= 0.001) continue;
    vec4 O = openings[i];
    vec2 r = (p - O.xy) / O.zw;
    float e = length(r);
    if (revealStyle > 0.5) {
      float z = exp(-e * e * 1.1) * openK[i];
      if (i == 0) { wv *= 1.0 - 0.85 * z; hole = max(hole, z * calmDim); }
      else glow += exp(-e * e * 2.2) * openK[i];
    } else {
      float h = smoothstep(1.0, 0.55, e) * openK[i];
      wv += normalize(p - O.xy + 0.001) * h * O.z * 0.35;
      hole = max(hole, h * 0.94);
      rim += exp(-pow((e - 1.0) / 0.1, 2.0)) * openK[i];
    }
  }

  // mode 2: the floor broken into big shards, each reflecting from a slightly different angle
  float grout = 1.0;
  if (mode > 1.5 && mode < 2.5) {
    vec2 g = p / cell, gi = floor(g), gf = fract(g);
    float d1 = 9.0, d2 = 9.0; vec2 best = vec2(0.0);
    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
      vec2 o = vec2(float(i), float(j));
      vec2 pt = o + hash2(gi + o);
      float dd = length(gf - pt);
      if (dd < d1) { d2 = d1; d1 = dd; best = gi + o; } else if (dd < d2) d2 = dd;
    }
    vec2 h = hash2(best) - 0.5;
    wv += h * cell * 0.35;                           // each shard tilted its own way
    grout = smoothstep(0.0, 0.05, d2 - d1);          // thin dark joints between them
  }

  // each drifting word stirs the glaze a little: slow rings around it, and the reflection under it brightens
  float under = 0.0;
  for (int i = 0; i < 10; i++) {
    if (float(i) >= nWordPts) break;
    vec3 W = wordPts[i];
    vec2 dv = p - W.xy;
    float d = length(dv);
    wv += dv / (d + 1.0) * sin(d / 85.0 - time * 1.2) * exp(-d / 260.0) * W.z * 14.0 * wordRipple;
    under += exp(-d * d / (300.0 * 300.0)) * W.z;
  }

  vec2 q = p + wv;
  vec3 c = vec3(0.0);
  float d;
  // the mural wall reflects far into the room; the side walls (only partly covered by the mural)
  // just along their foot, very soft, so the end of their mural never draws an edge on the floor
  d = q.x;          c += sampleWall(w1, D - q.y, D, d, stretch, blur) * exp(-d / reach);
  d = q.y;          c += sampleWall(w2, q.x, W, d, stretch * 0.45, blur * 5.0) * exp(-d / reach) * 0.8;
  d = D - q.y;      c += sampleWall(w4, W - q.x, W, d, stretch * 0.45, blur * 5.0) * exp(-d / reach) * 0.8;

  // the colours of the reflection: more saturated, and the dull haze between them pushed down
  float lc = dot(c, vec3(0.3, 0.59, 0.11));
  c = max(vec3(0.0), lc + (c - lc) * colSat);
  float pk = max(max(c.r, c.g), max(c.b, 0.0001));
  c *= pow(min(pk, 1.0), colContrast - 1.0);

  float k = strength * (1.0 - 0.4 * dimK) * (1.0 + 0.45 * wordRipple * under);
  if (mode > 2.5) k *= 1.0 + 6.0 * waveBoost;        // mode 3: the reflections wake up where the wave passes
  vec3 col = c * k * grout + waveLight * (mode > 2.5 ? 0.55 : 0.32) * (1.0 - 0.6 * dimK);

  // the words set into the glaze: read where the warped surface puts them, lit by the reflection
  // around them (brighter over the mural's light, faint in the dark), breathing slowly along their letters
  if (wordsOn > 0.5) {
    vec2 tu = q / room.xy;
    vec2 tw = clamp(tu, vec2(0.0), vec2(1.0));
    vec4 wt = texture2D(wordsTex, vec2(tw.x, flipY > 0.5 ? 1.0 - tw.y : tw.y));
    float inside = step(0.0, tu.x) * step(tu.x, 1.0) * step(0.0, tu.y) * step(tu.y, 1.0);   // (past the edge of the floor the layer's last row would be stretched into streaks)
    float wc = wt.a * inside * (0.82 + 0.18 * sin(p.x * 0.004 + p.y * 0.0031 + time * 0.35));
    float lum = dot(c * k, vec3(0.3, 0.59, 0.11));
    float poemK = clamp(1.0 - wt.g / max(wt.b, 0.004), 0.0, 1.0);
    vec3 wcol = mix(amber, poemCol, poemK) * (wordBase + 2.0 * lum) * wordLight + c * k * 0.45;
    wcol = mix(wcol, bright * 1.25, wt.r);
    col = col * (1.0 - 0.3 * wc) + wcol * wc;
  }
  col *= 1.0 - hole;
  col += rimCol * (rim * 0.06 + glow * wordGlow);
  gl_FragColor = vec4(col, 1.0);
}
