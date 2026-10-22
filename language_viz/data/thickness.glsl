// thickness.glsl — the trencadís has a body (Mural.pde: drawThickness)
// Like a real tile seen a little from above: under the glazed face its fired-clay body shows as a thin,
// crisp band, the same width and direction all round the mural and the border (down and slightly to
// the right, the light coming from the upper left), its clay darker towards the back; past it a faint
// contact shadow. Read from the layer itself, at full resolution: sharp, never blurred.
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER
// (uniforms prefixed with u: plain names clash with Processing's own)
uniform sampler2D texture;   // the layer (alpha = there is a tile)
uniform vec2  uOff;          // the body's depth as an offset in texture coordinates (down-right on the wall)
uniform vec3  uClay;
uniform float uShadow;
uniform sampler2D uSoft;     // the layer, small and soft (Mural.pde): the glaze's colour along the edge
uniform float uGlaze;         // the share of the side that is still glaze, rolling over (the rest is clay)
varying vec4 vertTexCoord;
void main() {
  vec2 st = vertTexCoord.st;
  float front = texture2D(texture, st).a;
  if (front > 0.995) discard;                // the glazed face is drawn over it
  // the body: how far up-left (along the depth) the tile begins — found, then refined: smooth, no steps
  float side = 0.0, k0 = 1.0, lo = 0.0;
  for (int k = 1; k <= 16; k++) {
    float f = float(k) / 16.0;
    float a = texture2D(texture, st - uOff * f).a;
    if (a > 0.5) { side = 1.0; k0 = f; lo = f - 1.0 / 16.0; break; }
  }
  if (side > 0.0) {
    float hi = k0;
    for (int i = 0; i < 5; i++) {
      float m = 0.5 * (lo + hi);
      if (texture2D(texture, st - uOff * m).a > 0.5) hi = m; else lo = m;
    }
    k0 = hi;
    float edge = texture2D(texture, st - uOff).a;     // the outer outline, smooth (no jagged steps)
    float alpha = smoothstep(0.05, 0.6, edge) * (1.0 - front);
    // the glaze rolling over the edge: the tile's own colour (looked for past the joint at its rim)
    // the colour of the glaze here: from a small, softened copy of the layer (uSoft) — the shards'
    // colours carried down the side evenly, no streaks; a touch richer, as glaze seen at an angle
    vec2 B = st - uOff * (k0 + 0.8);
    vec4 t = texture2D(uSoft, B);
    vec3 best = t.rgb / max(t.a, 0.001);
    float m = dot(best, vec3(0.333));
    best = clamp(m + (best - m) * 1.35, 0.0, 1.0);
    float turn = clamp(k0 / uGlaze, 0.0, 1.0);        // 0 just under the face … 1 where it meets the clay
    vec3 glaze = best * mix(0.64, 0.35, pow(turn, 0.8));   // starting in the bevel's tone at a lower edge, darker as it turns away
    float into = clamp((k0 - uGlaze) / (1.0 - uGlaze), 0.0, 1.0);
    vec3 clay = uClay * mix(1.0, 0.7, into);
    vec3 c = mix(glaze, clay, smoothstep(uGlaze - 0.05, uGlaze + 0.05, k0));
    gl_FragColor = vec4(c, alpha);
    return;
  }
  // a faint contact shadow just beyond it
  float sh = 0.0;
  for (int k = 1; k <= 4; k++) sh = max(sh, texture2D(texture, st - uOff * (1.0 + float(k) * 0.5)).a * (1.0 - float(k) / 5.0));
  if (sh < 0.004) discard;
  gl_FragColor = vec4(0.0, 0.0, 0.0, sh * uShadow);
}
