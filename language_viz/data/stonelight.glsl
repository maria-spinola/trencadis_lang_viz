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
uniform vec4  uFloor;        // the floor: (is floor, level in the middle, level at the walls, how far it darkens)
uniform vec2  uFloorSize;
uniform vec2  uFloorMural;   // the floor: level at the foot of WALL 1 (x = 0, the mural's reflection), how uneven the dark's edge is
varying vec4 vertTexCoord;
void main() {
  vec2 st = vertTexCoord.st;
  vec3 a = texture2D(texture, st).rgb / 0.8;
  vec3 nn = normalize(texture2D(uNormal, st).rgb * 2.0 - 1.0);
  float fill = max(dot(nn, normalize(vec3(-0.3, 0.2, 1.0))), 0.0);   // the steady light from above
  float sun = max(dot(nn, uSun), 0.0);
  float light = 0.6 + 0.3 * fill + uSunK * sun;
  vec3 warm = mix(vec3(1.0), vec3(1.05, 1.0, 0.92), clamp(sun * uSunK * 1.6, 0.0, 1.0));   // the sunlit stone a touch warmer
  float lv = uLevel;
  if (uFloor.x > 0.5) {   // darker towards the middle of the room, as bright as the walls at their foot
    vec2 p = st * uFloorSize;
    float S = min(uFloorSize.x, uFloorSize.y);
    vec4 dd = vec4(p.x, uFloorSize.x - p.x, p.y, uFloorSize.y - p.y) / S;   // to WALL 1, WALL 3, WALL 2, WALL 4
    // a soft minimum: rounded corners, never a square
    float k = 0.05;
    float d = -k * log(exp(-dd.x / k) + exp(-dd.y / k) + exp(-dd.z / k) + exp(-dd.w / k));
    // its edge uneven, in long slow curves
    float wob = sin(p.x * 0.0021 + 1.3) * sin(p.y * 0.0017 + 0.7) + 0.6 * sin((p.x - p.y) * 0.0012 + 2.1) + 0.4 * sin(p.y * 0.0043 + p.x * 0.0009);
    d += uFloorMural.y * uFloor.w * 0.45 * wob;
    // the level at the edge: darker where WALL 1's colours are reflected (nearest wall weighs most)
    vec4 w = exp(-dd / 0.08);
    float edge = (w.x * uFloorMural.x + (w.y + w.z + w.w) * uFloor.z) / (w.x + w.y + w.z + w.w);
    lv *= mix(edge, uFloor.y, smoothstep(0.0, uFloor.w, d));
  }
  gl_FragColor = vec4(a * light * warm * lv, uAlpha);
}
