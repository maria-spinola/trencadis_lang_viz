// smoke.glsl — the smoke behind the mural (Backdrop.pde, BACKDROP "glow")
// One field of smoke round the whole uRoom, so walls and floor never show an edge: every pixel of a
// surface is a point P of the uRoom; seen from the audience's eyes uEye, the smoke behind it lies further
// along the same ray (at a few depths). The smoke is sampled on a cylinder round the uRoom (angle round
// the uCentre, height): it turns slowly round the uRoom, the far depths slower. Its colour is the
// trencadís' glazes mixed into each other by another slow field.
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER
// (its uniforms are prefixed with u: plain names like "scale" or "time" clash with Processing's own and gave an OpenGL error)

uniform sampler2D texture;   // (dummy)
uniform vec2  uFace;
uniform vec3  uOrg, uAxU, uAxV;     // the surface in the uRoom: P = uOrg + uAxU·u + uAxV·v
uniform vec3  uEye;             // the eyes
uniform vec2  uCentre;        // the uRoom's uCentre (x, y)
uniform float uIsFloor;
uniform vec2  uRoom;          // W, D (floor: how far from the walls it reaches)
uniform float uReach;
uniform float uTime, uDrift, uLevel, uWallH, uScale, uDensity, uSoft, uSat, uHaze;
uniform vec3  uPal[8];
uniform float uNPal;
uniform float uFlipY;
uniform float uMode;          // 0 smoke · 2 natural stone
uniform vec3  uStone[4];      // the stone's colours
uniform sampler2D uStoneTex;  // a photograph of stone (data/stone.jpg), if there is one
uniform float uHasStoneTex;
uniform sampler2D uRock, uGrain, uSlate;   // photographs of stone (data/stone_rock/grain/slate.jpg): their detail and relief
uniform float uHasPhotos;
uniform float uRough;         // the stone: how rough its relief is (STONE_ROUGHNESS)
uniform float uOut;           // the stone: 0 lit · 1 its colour only · 2 its relief (normals) — the light is then added each frame (stonelight.glsl)

varying vec4 vertTexCoord;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
  vec3 i = floor(x), f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
                 mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
             mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                 mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + vec3(1.7, 9.2, 3.1); a *= 0.5; }
  return s;
}
vec3 palette(float k) {
  k = fract(k) * uNPal;
  int i = int(floor(k));
  float f = smoothstep(0.0, 1.0, fract(k));
  vec3 a = uPal[0], b = uPal[1];
  for (int j = 0; j < 8; j++) {
    if (float(j) == float(i)) a = uPal[j];
    if (float(j) == mod(float(i) + 1.0, uNPal)) b = uPal[j];
  }
  return mix(a, b, f);
}


// ── natural stone: the walls and the floor themselves (drawn once: it is still; the light is added each frame) ──
// Good gradient noise (no lattice), sedimentary layers of uneven thickness each with its own tone, fine
// grain, a little relief lit from above; or, if data/stone.jpg exists, that photograph tiled on the rock.
vec3 ghash(vec3 p) {
  p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float gnoise(vec3 p) {
  vec3 i = floor(p), f = fract(p);
  vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  return mix(mix(mix(dot(ghash(i + vec3(0,0,0)), f - vec3(0,0,0)), dot(ghash(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
                 mix(dot(ghash(i + vec3(0,1,0)), f - vec3(0,1,0)), dot(ghash(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x), u.y),
             mix(mix(dot(ghash(i + vec3(0,0,1)), f - vec3(0,0,1)), dot(ghash(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
                 mix(dot(ghash(i + vec3(0,1,1)), f - vec3(0,1,1)), dot(ghash(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x), u.y), u.z) * 0.5 + 0.5;
}
float gfbm(vec3 p, int oct) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 7; i++) { if (i >= oct) break; s += a * gnoise(p); p = p * 2.02 + vec3(3.1, 1.7, 5.3); a *= 0.5; }
  return s;
}
float rockH(vec3 q) { return gfbm(q * 0.0011, 5) * 0.85 + gfbm(q * 0.004, 3) * 0.15; }
// a photograph tiled without seams (and without mirroring): near the edges of each tile it fades into a
// copy of itself shifted by half, whose middle is where the tile's edges are
float photo(sampler2D t, vec2 uv) {
  vec2 f = fract(uv), g = fract(uv + 0.5);
  float m = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
  float w = smoothstep(0.02, 0.22, m);
  float a = dot(texture2D(t, f).rgb, vec3(0.3, 0.59, 0.11)), b = dot(texture2D(t, g).rgb, vec3(0.3, 0.59, 0.11));
  return mix(b, a, w);
}
// the photographs' stone at a point: rough rock for the shape, slate and grain over it at other scales
// (so it never shows the same pattern twice)
float stonePhoto(vec2 uv) {
  float r = photo(uRock, uv / 1100.0);
  float s = photo(uSlate, uv / 2300.0 + 0.37);
  float g = photo(uGrain, uv / 3000.0 + 0.71);
  return r * 0.25 + s * 0.35 + g * 0.4;   // a calm, fine stone, ~1 pixel of photo per pixel of wall: sharp
}

vec3 stone(vec3 P) {
  vec3 dir = normalize(P - uEye);
  float k0 = 1700.0;
  vec3 lo = vec3(-k0, -k0, -500.0), hi = vec3(uRoom.x + k0, uRoom.y + k0, uWallH + 2200.0);
  vec3 t1 = (lo - uEye) / dir, t2 = (hi - uEye) / dir;
  vec3 tm = max(t1, t2);
  float t = min(tm.x, min(tm.y, tm.z));
  vec3 X = uEye + dir * t;
  vec3 n; vec2 uv;
  if (t == tm.z) { n = vec3(0.0, 0.0, dir.z > 0.0 ? -1.0 : 1.0); uv = X.xy; }
  else if (t == tm.x) { n = vec3(dir.x > 0.0 ? -1.0 : 1.0, 0.0, 0.0); uv = vec2(X.y, X.z); }
  else { n = vec3(0.0, dir.y > 0.0 ? -1.0 : 1.0, 0.0); uv = vec2(X.x, X.z); }
  // the stone is the surface itself — the floor, and the walls (so a block of it can move, open, fall)
  float K = 1.0;
  if (uIsFloor > 0.5) { X = P; n = vec3(0.0, 0.0, 1.0); uv = P.xy; t = length(P - uEye); }
  else {
    vec3 nc = normalize(cross(uAxU, uAxV));
    n = dot(nc, uEye - P) > 0.0 ? nc : -nc;             // facing the room
    X = P; t = length(P - uEye);
    uv = abs(n.x) > 0.5 ? vec2(P.y, P.z) : vec2(P.x, P.z);
    K = 1.8;                                            // (the grain the same size it had seen further away)
  }
  vec3 q = X * K / uScale;
  vec2 pu = uv * K / uScale;
  // the colour: layers of stone of uneven thickness, each its own tone, mottled (the palette, STONE_COLORS)
  float w = gfbm(q * 0.0009 + 4.2, 4);
  float layer = (q.z + w * 600.0) / 330.0;
  float li = floor(layer), lf = fract(layer);
  float tone = fract(sin(li * 12.9898) * 43758.5453);
  vec3 base = mix(uStone[0], uStone[1], tone);
  if (uHasPhotos > 0.5) base = mix(mix(uStone[0], uStone[1], smoothstep(0.3, 0.7, gfbm(q * 0.0007 + 2.9, 4))), base, 0.4);   // broad patches, the layers only hinted
  float mott = gfbm(q * 0.003 + li * 1.3, 4);
  base = mix(base, uStone[2], smoothstep(0.45, 0.8, mott) * 0.45);
  base = mix(base, uStone[3], smoothstep(0.62, 0.8, gfbm(q * 0.0025 + 9.1, 4)) * 0.3);
  float light;
  vec3 nn;
  if (uHasPhotos > 0.5) {
    // the detail and the relief come from the photographs: their light and shade, and the slope of the rock
    float L0 = stonePhoto(pu);
    float e = 3.0;
    float lx = stonePhoto(pu + vec2(e, 0.0)), ly = stonePhoto(pu + vec2(0.0, e));
    base *= 0.35 + 1.0 * L0;                                   // the photo's own light and shade, at full contrast
    vec3 tu = n.z != 0.0 ? vec3(1.0, 0.0, 0.0) : (n.x != 0.0 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0));
    vec3 tv = n.z != 0.0 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
    nn = normalize(n - (tu * (lx - L0) + tv * (ly - L0)) * 4.5 * uRough);   // a fine relief
    light = 0.62 + 0.45 * max(dot(nn, normalize(vec3(-0.3, 0.2, 1.0))), 0.0);
    base *= 0.94 + 0.06 * smoothstep(0.0, 0.05, lf) * smoothstep(1.0, 0.9, lf);   // the faintest seam between layers
  } else {
    float seam = smoothstep(0.0, 0.05, lf) * smoothstep(1.0, 0.9, lf);
    base *= 0.62 + 0.38 * seam;
    base *= 0.95 + 0.1 * gnoise(q * 0.03);
    float ee = 6.0, h0 = rockH(q);
    vec3 tu = n.z != 0.0 ? vec3(1.0, 0.0, 0.0) : (n.x != 0.0 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0));
    vec3 tv = n.z != 0.0 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
    float du = (rockH(q + tu * ee) - h0) / ee, dv = (rockH(q + tv * ee) - h0) / ee;
    nn = normalize(n - (tu * du + tv * dv) * 1500.0);
    light = 0.55 + 0.55 * max(dot(nn, normalize(vec3(-0.3, 0.2, 1.0))), 0.0);
  }
  // the corners of the room in a little shade (where two walls, or a wall and the floor, meet)
  vec3 dd = min(X, vec3(uRoom, uWallH) - X);
  float edge = n.x != 0.0 ? min(dd.y, dd.z) : (n.y != 0.0 ? min(dd.x, dd.z) : min(dd.x, dd.y));
  float ao = mix(0.55, 1.0, smoothstep(0.0, 700.0, edge));
  float fog = exp(-t / 14000.0);
  vec3 albedo = base * mix(0.5, 1.0, ao) * mix(0.55, 1.0, fog);
  if (uOut > 1.5) return nn * 0.5 + 0.5;
  if (uOut > 0.5) return albedo * 0.8;   // (×0.8: room for the brightest stone in 8 bits)
  return albedo * light;
}


void main() {
  vec2 st = vertTexCoord.st;
  vec2 uv = vec2(st.x, uFlipY > 0.5 ? 1.0 - st.y : st.y) * uFace;
  vec3 P = uOrg + uAxU * uv.x + uAxV * uv.y;
  vec3 col = vec3(0.0);
  float U = 650.0 * uScale;                                   // uRoom units per unit of the noise (the size of its swirls)
  float R = 2.0 * (uRoom.x + uRoom.y) / 6.2831853 / U;          // the cylinder the smoke lives on (as long round as the uRoom)
  // on the floor: the smoke is read on the floor itself, as if the walls went on down into it
  // (seen through the eye it would stream out in straight rays from the uCentre)
  float dw = min(min(P.x, uRoom.x - P.x), min(P.y, uRoom.y - P.y));   // distance to the nearest wall
  if (uMode > 1.5) col = stone(P);
  else for (int L = 0; L < 3; L++) {
    float D = (L == 0) ? 2.4 : (L == 1 ? 1.1 : 0.4);   // how far behind the surface (× the eye's distance)
    vec3 Q = uEye + (P - uEye) * (1.0 + D);
    if (uIsFloor > 0.5) Q = vec3(P.xy, -dw * 0.8);
    float ang = atan(Q.y - uCentre.y, Q.x - uCentre.x) + uTime * uDrift * (L == 0 ? 0.35 : (L == 1 ? 0.6 : 1.0));
    vec3 c = vec3(cos(ang) * R, sin(ang) * R, Q.z / U + float(L) * 7.0);
    float t = uTime * 0.035;
    // smoke: a slow field bent by another one (curling, never geometric)
    vec3 q = vec3(fbm(c * 0.9 + vec3(0.0, 0.0, t)), fbm(c * 0.9 + vec3(5.2, 1.3, -t)), fbm(c * 0.9 + vec3(2.1, 7.7, t * 0.7)));
    float d = fbm(c * 1.1 + q * 2.6 + vec3(t * 0.5, 0.0, 0.0));
    d = smoothstep(uDensity, uDensity + uSoft, d);
    vec3 tint = palette(fbm(c * 0.35 + q * 0.8 + vec3(0.0, t * 0.3, 0.0)) * 1.6 + float(L) * 0.31);
    tint = mix(vec3(dot(tint, vec3(0.3, 0.59, 0.11))), tint, uSat);   // muted, as smoke takes colour from the light
    float w = (L == 0) ? 0.45 : (L == 1 ? 0.7 : 1.0);   // the far smoke dimmer
    col += tint * (uHaze + (1.0 - uHaze) * d) * w / 2.15;   // a veil everywhere, the wisps over it (no black holes)
  }
  if (uMode > 1.5 && uOut > 0.5) { gl_FragColor = vec4(col, 1.0); return; }   // the stone's colour or relief, as it is
  col *= uLevel;
  if (uIsFloor > 0.5 && uMode < 1.5) {   // on the floor: tongues of smoke from the walls, uneven (never a square), the rest black
    vec2 fp = P.xy / (900.0 * uScale);
    float n1 = fbm(vec3(fp * 0.9, uTime * 0.015)), n2 = fbm(vec3(fp * 2.1 + 3.7, -uTime * 0.02));
    float r = uReach * (0.2 + 1.9 * n1 * n1 + 0.5 * n2);   // how far it comes in, here: from almost nothing to deep tongues
    col *= 1.0 - smoothstep(r * 0.15, r, dw);
  } else {               // on the walls: fading towards the top (behind the border)
    float h = P.z / uWallH;
    col *= 1.0 - (uMode > 0.5 ? 0.15 : 0.35) * smoothstep(0.6, 1.0, h);
  }
  gl_FragColor = vec4(col, 1.0);
}
