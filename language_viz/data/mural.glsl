// mural.glsl — the trencadís mural lit live (Mural.pde)
// The colour of the mural (already baked with its own light) is lit again by moving lights,
// using the relief map baked with every tile: RGB = the normal of each shard, A = how glossy.
// So the glaze shines and the edges catch the light as the lights move; the mortar stays matte.
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;     // the mural
uniform sampler2D normalMap;   // its relief: normal x, y (rg), gloss (b)
uniform vec2  faceSize;        // the wall, in room units
uniform float flipY;           // 1 if the texture rows are upside down
uniform float ringOffset;      // where this wall starts along the mural (WALL 4 → 1 → 2); < 0: no waves here

uniform float nLights;
uniform vec4  lights[8];       // x, y (wall units), height, intensity
uniform vec3  lightCols[8];

uniform float nWaves;
uniform vec4  waves[4];        // centre along the mural, centre height, radius, intensity
uniform float waveWidth;
uniform vec3  warm;
uniform float shininess;
uniform float relief;          // how much the relief shows under the live light

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
  vec2 st = vertTexCoord.st;
  vec4 c = texture2D(texture, st);
  if (c.a < 0.003) discard;
  vec4 nm = texture2D(normalMap, st);
  vec2 nxy = nm.rg * 2.0 - 1.0;                   // relief map: normal x, y in R, G; gloss in B
  vec3 n = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
  float gloss = nm.b;
  if (nm.a < 0.02) { n = vec3(0.0, 0.0, 1.0); gloss = 0.0; }
  vec2 uv = vec2(st.x, flipY > 0.5 ? 1.0 - st.y : st.y);
  vec2 p = uv * faceSize;
  vec3 base = c.rgb;
  vec3 col = base;

  // moving lights: a broad soft light and its reflection in the glaze
  for (int i = 0; i < 8; i++) {
    if (float(i) >= nLights) break;
    vec4 L = lights[i];
    vec3 d = vec3(L.xy - p, L.z);
    float dist2 = dot(d, d);
    vec3 l = d * inversesqrt(dist2);
    float fall = L.w / (1.0 + dist2 / (L.z * L.z * 2.0));
    float diff = max(dot(n, l), 0.0) - l.z * 0.9;          // only what the relief adds or takes
    vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
    float spec = pow(max(dot(n, h), 0.0), shininess) * gloss;
    col += lightCols[i] * fall * (base * diff * relief + spec * 1.3 + base * 0.05);
  }

  // waves of light running out along the mural from where a tile has settled
  if (ringOffset >= 0.0) {
    float X = ringOffset + p.x;
    for (int i = 0; i < 4; i++) {
      if (float(i) >= nWaves) break;
      vec4 W = waves[i];
      float dd = length(vec2(X - W.x, (p.y - W.y) * 1.6));
      float band = exp(-pow((dd - W.z) / waveWidth, 2.0));
      float trail = exp(-max(W.z - dd, 0.0) / (waveWidth * 2.0)) * step(dd, W.z) * 0.18;   // a glow left behind it
      float k = W.w * (band + trail);
      vec3 l = normalize(vec3(sign(X - W.x) * 0.6, -0.4, 0.7));
      float spec = pow(max(dot(n, normalize(l + vec3(0.0, 0.0, 1.0))), 0.0), shininess * 0.6) * gloss;
      col += warm * k * (base * (0.12 + 0.75 * gloss) + spec * 1.6);   // the front shines in the glaze, the mortar stays darker
    }
  }
  gl_FragColor = vec4(col, c.a) * vertColor;
}
