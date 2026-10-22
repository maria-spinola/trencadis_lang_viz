// ═══════════════════════════════════════════════════════════
// Mural.pde
// The live light of the mural (shader data/mural.glsl). Every tile bakes a relief map
// (normal + gloss, Ceramic.pde), stamped into glossLayers next to its colour. The mural is
// then drawn lit by moving lights, so it reads as glazed ceramic, not as a picture:
//   - calm: a broad, slow light wandering along the mural (WALL 4 → 1 → 2 and back)
//   - the travelling stream carries its own warm light over the walls it passes
//   - a tile settling: a local light, and a wave of warm light running out along the bands
//     of the mural, across the corners onto the next walls, decaying slowly
// While someone interacts, the rest of the room calms down (interactK).
// Settings: "Art direction" in Config.pde.
// ═══════════════════════════════════════════════════════════

PShader muralShader;
float interactK = 0;                    // 0 calm … 1 a word is on its way
ArrayList<float[]> waves = new ArrayList<float[]>();   // { centre along the mural, height, start frame }
ArrayList<float[]> impacts = new ArrayList<float[]>(); // { face, x, y, start frame }
float flipYMural = 1;

boolean muralLit(Face f) {
  return art(ART_MURAL_LIGHT) && glossLayers[f.id] != null && mosaicLayers[f.id] != null;
}

// where a wall starts along the mural (WALL 4, then WALL 1, then WALL 2), −1 for the others
float ringOffsetOf(int face) { return sweepStart(face); }

void updateMural() {
  boolean busy = false;
  for (TileFlight fl : flights) busy |= !fl.landed;
  interactK = lerp(interactK, busy ? 1 : 0, busy ? 0.04 : 0.008);   // calms down slowly
  for (int i = waves.size() - 1; i >= 0; i--) if (frameCount - waves.get(i)[2] > WAVE_FRAMES) waves.remove(i);
  for (int i = impacts.size() - 1; i >= 0; i--) if (frameCount - impacts.get(i)[3] > WAVE_FRAMES) impacts.remove(i);
}

// A tile has settled in its slot (Moments.pde): a local light and a wave along the mural
void muralImpact(TrencadisTile t) {
  float ro = ringOffsetOf(t.face);
  if (ro >= 0) waves.add(new float[] { ro + t.origin.x, t.origin.y, frameCount });
  impacts.add(new float[] { t.face, t.origin.x, t.origin.y, frameCount });
}

// Draws the mural of a wall with the live light
void drawMuralLit(PGraphics pg, Face f) { drawLitLayer(pg, f, mosaicLayers[f.id], glossLayers[f.id], f.h); }

// Any layer of baked tiles with its relief (the mural, the border: Cenefa.pde), covering the wall from
// its top down to h (the border's layer is only as tall as the border)
void drawLitLayer(PGraphics pg, Face f, PGraphics colorLayer, PGraphics reliefLayer, float h) {
  pg.shader(muralShaderFor(f, reliefLayer, h));
  pg.image(colorLayer, 0, 0, f.w, h);
  pg.resetShader();
}

// The mural's shader set up for a wall's layer (also used for the tiles moving off the wall: WallMoments.pde)
PShader muralShaderFor(Face f, PGraphics reliefLayer, float h) {
  if (muralShader == null) muralShader = loadShader("mural.glsl");
  PShader sh = muralShader;
  sh.set("normalMap", reliefLayer);
  sh.set("faceSize", f.w, h);
  sh.set("flipY", flipYMural);
  sh.set("ringOffset", ringOffsetOf(f.id));
  sh.set("shininess", MURAL_SHININESS);
  sh.set("relief", MURAL_RELIEF);
  float[] wc = rgb01(WARM_LIGHT_COLOR);
  sh.set("warm", wc[0], wc[1], wc[2]);

  float[] L = new float[32], C = new float[24];
  int n = 0;
  // the calm light, wandering along the mural
  float ro = ringOffsetOf(f.id);
  if (ro >= 0 && AMBIENT_LIGHT > 0) {
    float total = 2 * ROOM_W + ROOM_D;
    float ph = (frameCount % AMBIENT_PERIOD) / (float) AMBIENT_PERIOD;
    float X = total * (0.5 - 0.5 * cos(TWO_PI * ph));
    float y = WALL_H * (0.3 + 0.12 * sin(TWO_PI * ph * 3));
    n = addLight(L, C, n, X - ro, y, WALL_H * 0.75, AMBIENT_LIGHT * (1 - 0.8 * max(interactK, fxDim)), rgb01(AMBIENT_LIGHT_COLOR));
  }
  // the travelling stream's light, on this wall
  for (TileFlight fl : flights) {
    if (fl.state != FLIGHT_TRAVEL || fl.onMainWall()) continue;
    for (int g = 0; g < fl.frags.size() && n < 7; g += max(1, fl.frags.size() / 3)) {
      Fragment fr = fl.frags.get(g);
      if (fr.pos == null) continue;
      PVector q = f.localPoint(fr.pos, faces[fr.face]);
      if (q == null || q.x < -WALL_H || q.x > f.w + WALL_H) continue;
      float lift = sin(PI * easeInOutCubic(fr.p));
      n = addLight(L, C, n, q.x, q.y, WALL_H * 0.35, TRAVEL_LIGHT * lift, wc);
    }
  }
  // the light where a tile has just settled
  for (float[] im : impacts) {
    if ((int) im[0] != f.id || n >= 8) continue;
    float t = (frameCount - im[3]) / (float) WAVE_FRAMES;
    n = addLight(L, C, n, im[1], im[2], WALL_H * 0.28, IMPACT_LIGHT * pow(1 - t, 2.6) * smooth01(t / 0.03), wc);
  }
  sh.set("nLights", (float) n);
  sh.set("lights", L, 4);
  sh.set("lightCols", C, 3);

  float[] Wv = new float[16];
  int nw = 0;
  for (float[] w : waves) {
    if (nw >= 4) break;
    float t = (frameCount - w[2]) / (float) WAVE_FRAMES;
    Wv[nw * 4] = w[0]; Wv[nw * 4 + 1] = w[1];
    Wv[nw * 4 + 2] = WAVE_REACH * (0.25 * (1 - pow(1 - t, 3)) + 0.75 * t);   // a quick start, then an even pace along the bands
    Wv[nw * 4 + 3] = IMPACT_WAVE * pow(1 - t, 1.3) * smooth01(t / 0.02);
    nw++;
  }
  sh.set("nWaves", (float) nw);
  sh.set("waves", Wv, 4);
  sh.set("waveWidth", WAVE_WIDTH);
  return sh;
}

int addLight(float[] L, float[] C, int n, float x, float y, float z, float k, float[] col) {
  if (n >= 8 || k <= 0.001) return n;
  L[n * 4] = x; L[n * 4 + 1] = y; L[n * 4 + 2] = z; L[n * 4 + 3] = k;
  C[n * 3] = col[0]; C[n * 3 + 1] = col[1]; C[n * 3 + 2] = col[2];
  return n + 1;
}

float[] rgb01(String hex) {
  int c = hexColor(hex);
  return new float[] { ((c >> 16) & 255) / 255.0, ((c >> 8) & 255) / 255.0, (c & 255) / 255.0 };
}

// The trencadís has a body (data/thickness.glsl): like a real tile seen a little from above, under every
// glazed edge of the mural and of the border its fired-clay body shows as a thin, crisp band, the same
// width and direction everywhere, with a faint shadow past it. One light pass per layer.
// MURAL_THICK in Config.pde (0 = flat).
PShader thickShader;
java.util.HashMap<PGraphics, PGraphics> thickSoft = new java.util.HashMap<PGraphics, PGraphics>();

// a small soft copy of each layer (its colours, for the sides), refreshed now and then (the mural changes
// slowly) — made BEFORE the walls are drawn (language_viz.pde): never inside another drawing (it flickered)
void updateThickSoft() {
  if (MURAL_THICK <= 0 && MURAL_BEVEL <= 0) return;
  int i = 0;
  for (PGraphics[] arr : new PGraphics[][] { mosaicLayers, cenefaLayers }) for (PGraphics L : arr) {
    i++;
    if (L == null) continue;
    PGraphics s = thickSoft.get(L);
    if (s != null && (frameCount + i * 7) % 45 != 0) continue;
    if (s == null) { s = createGraphics(max(8, L.width / 10), max(4, L.height / 10), P2D); thickSoft.put(L, s); }
    s.beginDraw();
    s.clear();
    s.blendMode(REPLACE);
    s.image(L, 0, 0, s.width, s.height);
    s.filter(BLUR, 1.5);   // (the side's colour changes gently from shard to shard: no bands)
    s.endDraw();
  }
}
PGraphics softOf(PGraphics L) { return thickSoft.get(L); }

void drawThickness(PGraphics pg, Face f) {
  if (MURAL_THICK <= 0 || f.id == FLOOR) return;
  if (thickShader == null) thickShader = loadShader("thickness.glsl");
  float[] cl = rgb01(BODY_TERRACOTTA);
  PGraphics[] layers = { mosaicLayers[f.id], CENEFA ? cenefaLayers[f.id] : null };
  for (PGraphics L : layers) {
    if (L == null) continue;
    float h = L.height / RENDER_SCALE;
    // down and a little to the right on the wall (texture y runs the other way when flipped)
    float ox = MURAL_THICK * 0.38 / f.w, oy = MURAL_THICK * 0.92 / h;
    thickShader.set("uOff", ox, flipYMural > 0.5 ? -oy : oy);
    thickShader.set("uClay", cl[0], cl[1], cl[2]);
    thickShader.set("uShadow", MURAL_THICK_SHADOW);
    thickShader.set("uGlaze", 1.0);
    if (softOf(L) == null) continue;
    thickShader.set("uSoft", softOf(L));   // (all glaze: no clay band)
    pg.shader(thickShader);
    pg.image(L, 0, 0, f.w, h);
    pg.resetShader();
  }
}

// The glazed face rounds over at the outer edges of the mural and the border (data/bevel.glsl), drawn
// over them: a highlight where the edge faces the light, a shade where it faces away. MURAL_BEVEL.
PShader bevelShader;

void drawBevel(PGraphics pg, Face f, PGraphics L) {
  if (MURAL_BEVEL <= 0 || L == null) return;
  if (bevelShader == null) bevelShader = loadShader("bevel.glsl");
  float h = L.height / RENDER_SCALE;
  if (softOf(L) == null) return;
  bevelShader.set("uSoft", softOf(L));
  bevelShader.set("uR", MURAL_BEVEL / f.w, MURAL_BEVEL / h);
  bevelShader.set("uFlipY", flipYMural);
  bevelShader.set("uLight", MURAL_BEVEL_LIGHT);
  bevelShader.set("uDark", MURAL_BEVEL_LIGHT * 0.9);
  pg.shader(bevelShader);
  pg.image(L, 0, 0, f.w, h);
  pg.resetShader();
}
