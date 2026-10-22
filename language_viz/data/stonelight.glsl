// stonelight.glsl — the stone lit by a slow, low light going round the room (Backdrop.pde: drawStone)
// The stone's colour and its relief are made once (smoke.glsl, uOut 1 and 2); here, each frame, a raking
// light — like the sun through a high window, crossing the room over minutes — lights them: the wall it
// faces warms and its grain stands out in relief, the others rest in a soft light from above.
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER
uniform sampler2D texture;   // the stone's colour (×0.8)
uniform sampler2D uNormal;   // its relief: normals ×0.5 + 0.5
uniform vec3  uSun;          // towards the travelling light
uniform float uSunK;         // how strong it is
uniform float uLevel;
uniform float uAlpha;        // (a patch of stone over something: how much)
varying vec4 vertTexCoord;
void main() {
  vec2 st = vertTexCoord.st;
  vec3 a = texture2D(texture, st).rgb / 0.8;
  vec3 nn = normalize(texture2D(uNormal, st).rgb * 2.0 - 1.0);
  float fill = max(dot(nn, normalize(vec3(-0.3, 0.2, 1.0))), 0.0);   // the steady light from above
  float sun = max(dot(nn, uSun), 0.0);
  float light = 0.6 + 0.3 * fill + uSunK * sun;
  vec3 warm = mix(vec3(1.0), vec3(1.05, 1.0, 0.92), clamp(sun * uSunK * 1.6, 0.0, 1.0));   // the sunlit stone a touch warmer
  gl_FragColor = vec4(a * light * warm * uLevel, uAlpha);
}
