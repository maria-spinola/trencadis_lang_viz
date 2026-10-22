// bevel.glsl — the glazed face rounds over at its edge, like a real tile (Mural.pde: drawBevel)
// Drawn over the mural and the border: within MURAL_BEVEL of an outer edge the glaze curves down —
// lighter where the edge faces the light (upper left), darker where it faces away, strongest right at
// the edge. Only near edges (most pixels leave after a few samples).
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER
// (uniforms prefixed with u: plain names clash with Processing's own)
uniform sampler2D texture;   // the layer (alpha = there is a tile)
uniform vec2  uR;            // the bevel's width, in texture coordinates (x, y)
uniform float uFlipY, uLight, uDark;
uniform sampler2D uSoft;     // the layer, small and soft: the glaze's colour near the edge
varying vec4 vertTexCoord;
void main() {
  vec2 st = vertTexCoord.st;
  if (texture2D(texture, st).a < 0.5) discard;
  // quick test: is any edge within reach?
  float far = 0.0;
  for (int i = 0; i < 8; i++) {
    float a = 6.2831853 * float(i) / 8.0;
    far += texture2D(texture, st + vec2(cos(a), sin(a)) * uR).a;
  }
  if (far > 7.95) discard;
  // distance to the edge (in steps) and the way out
  vec2 out2 = vec2(0.0); float dmin = 1.0;
  for (int k = 1; k <= 6; k++) {
    float r = float(k) / 6.0;
    for (int i = 0; i < 12; i++) {
      float a = 6.2831853 * float(i) / 12.0;
      vec2 d = vec2(cos(a), sin(a));
      if (texture2D(texture, st + d * uR * r).a < 0.5) { out2 += d / r; dmin = min(dmin, r); }
    }
  }
  if (dmin >= 1.0) discard;
  vec2 n = normalize(out2 + 0.00001);
  if (uFlipY > 0.5) n.y = -n.y;              // to wall directions (y down)
  float facing = dot(n, normalize(vec2(-0.6, -0.8)));   // +1 the edge faces the light
  float curve = 1.0 - dmin;                  // 0 where the bevel starts … 1 at the edge
  curve = curve * curve;
  // the rounded glaze: near the edge the glaze itself (over the rim of mortar), lighter where the edge faces
  // the light, darker where it faces away — ending in the same tone the side starts with (no line between)
  vec4 t = texture2D(uSoft, st);
  vec3 g = t.rgb / max(t.a, 0.001);
  float m = dot(g, vec3(0.333));
  g = clamp(m + (g - m) * 1.35, 0.0, 1.0);
  float shade = facing > 0.0 ? 1.0 + uLight * 0.45 * facing : 1.0 - uDark * 0.5 * -facing;
  float cover = smoothstep(0.35, 0.85, curve);   // the outermost part fully glaze (the mortar rim hidden)
  vec3 c = g * mix(1.0, shade, curve);
  gl_FragColor = vec4(c, max(cover, curve * 0.6));
}
