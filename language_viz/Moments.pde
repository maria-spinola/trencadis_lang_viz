// ═══════════════════════════════════════════════════════════
// Moments.pde
// What makes people go "ooh":
//   - their tile lights up when it settles in the mural, with their word beside it
//   - typing a word again lights up the tiles it already has in the mural
//   - a rare or very Catalan word is announced, assembles slower, with a golden sheen
//   - a slow light sweeps over the mural, catching glazes, gold and glass
//   - when the mural is full: it glows, a chord, and a new layer begins
//   - now and then a verse of the poem forms on the floor, word by word
// Settings: "The journey and the moments" in Config.pde.
// ═══════════════════════════════════════════════════════════

// ── A tile lighting up in the mural, its word beside it ──

class LandMark {
  int face;
  float[] xs, ys;              // outline on its wall
  float cx, bot, h;            // centre x, lowest point, height
  String word;
  int t0, dur;
  boolean again;               // an older tile of a word typed again (pulses twice)
}

ArrayList<LandMark> marks = new ArrayList<LandMark>();

LandMark newMark(int face, ArrayList<PVector> outline, String word, int dur, boolean again) {
  LandMark m = new LandMark();
  m.face = face; m.word = word; m.t0 = frameCount; m.dur = dur; m.again = again;
  int n = outline.size();
  m.xs = new float[n]; m.ys = new float[n];
  float x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
  for (int i = 0; i < n; i++) {
    m.xs[i] = outline.get(i).x; m.ys[i] = outline.get(i).y;
    x0 = min(x0, m.xs[i]); x1 = max(x1, m.xs[i]); y0 = min(y0, m.ys[i]); y1 = max(y1, m.ys[i]);
  }
  m.cx = (x0 + x1) / 2; m.bot = y1; m.h = y1 - y0;
  return m;
}

// The tile has just settled in its slot (Mosaic.pde)
void addLandMark(TrencadisTile t, String word) {
  ArrayList<PVector> o = new ArrayList<PVector>();
  for (int i = 0; i < t.gx.length; i++) o.add(new PVector(t.gx[i] + t.origin.x, t.gy[i] + t.origin.y));
  marks.add(newMark(t.face, o, word, LAND_GLOW_FRAMES, false));
  if (art(ART_MURAL_LIGHT)) muralImpact(t);   // Mural.pde: local light + wave along the mural
  echoImpact(t, java.awt.Color.HSBtoRGB(t.cBase[0] / 360f, t.cBase[1] / 100f, t.cBase[2] / 100f), word);   // FloorEcho.pde
}

// A word typed again: its tiles already in the mural light up ("la meva encara hi és")
void addWordMarks(String word) {
  if (word == null || word.length() == 0) return;
  int found = 0;
  for (int i = 0; i < mosaicTiles.size() - 1 && found < 12; i++) {   // (the last one is the new tile)
    JSONObject rec = mosaicTiles.getJSONObject(i);
    if (!rec.getString("word", "").equalsIgnoreCase(word) || !rec.hasKey("slot")) continue;
    if (rec.getInt("cycle", 0) < mosaicCycle - 1) continue;          // long covered
    int slot = rec.getInt("slot");
    Patch p = partPatch(slot, rec.getInt("part", PART_WHOLE), rec.getInt("slot2", -1));
    marks.add(newMark(slotFaces.get(slot), p.outline(), word, AGAIN_GLOW_FRAMES, true));
    found++;
  }
  if (found > 0) println("\"" + word + "\" was already in the mural " + found + " time(s): lit up");
}

void drawMarks(PGraphics pg, Face f) {
  for (int k = marks.size() - 1; k >= 0; k--) {
    LandMark m = marks.get(k);
    float t = (frameCount - m.t0) / (float) m.dur;
    if (t >= 1) { marks.remove(k); continue; }
    if (m.face != f.id) continue;
    // the light: up quickly, down slowly; the older tiles pulse twice
    float a = m.again ? pow(sin(PI * t * 2), 2) * (1 - t * 0.4) : smooth01(t / (art(ART_IMPACT_WAVE) ? 0.08 : 0.04)) * pow(1 - t, 1.6);
    pg.blendMode(ADD);
    pg.noStroke();
    for (int ring = 2; ring >= 0; ring--) {   // a soft halo around it, the tile itself brighter
      float s = 1 + ring * 0.06;
      pg.fill(art(ART_IMPACT_WAVE) ? hexColor(WARM_LIGHT_COLOR) : color(40, 40, 100), 100 * MARK_GLOW * a * (ring == 0 ? 1 : 0.25));
      pg.beginShape();
      for (int i = 0; i < m.xs.length; i++) pg.vertex(m.cx + (m.xs[i] - m.cx) * s, m.bot - m.h / 2 + (m.ys[i] - (m.bot - m.h / 2)) * s);
      pg.endShape(CLOSE);
    }
    pg.blendMode(BLEND);
    // the impact: a wave of light running out from it through the glazes and the ribbons of the mural
    if (!m.again && art(ART_IMPACT_WAVE) && !art(ART_MURAL_LIGHT)) {
      float tw = (frameCount - m.t0) / (float) IMPACT_FRAMES;
      if (tw < 1) drawGlossRing(pg, f, m.cx, m.bot - m.h / 2, lerp(m.h * 0.3, WALL_H * 2.2, easeOutQuad(tw)), WALL_H * 0.22, IMPACT_WAVE * pow(1 - tw, 1.5));
    }
  }
}

float easeOutQuad(float t) { t = constrain(t, 0, 1); return 1 - (1 - t) * (1 - t); }

// A soft round light (white, alpha falling off), tinted when drawn
PImage glowImg;
PImage glowSprite() {
  if (glowImg != null) return glowImg;
  int n = 64;
  glowImg = createImage(n, n, ARGB);
  glowImg.loadPixels();
  for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
    float d = dist(x + 0.5, y + 0.5, n / 2.0, n / 2.0) / (n / 2.0);
    float a = d >= 1 ? 0 : pow(1 - d * d, 2);
    glowImg.pixels[y * n + x] = (round(a * 255) << 24) | 0xFFFFFF;
  }
  glowImg.updatePixels();
  return glowImg;
}

// A ring of light (centre cx, cy; radius R; width w) that only lights what shines in the mural
void drawGlossRing(PGraphics pg, Face f, float cx, float cy, float R, float w, float k) {
  PGraphics G = glossLayers[f.id];
  if (G == null || k < 0.01) return;
  int cols = 72, rows = 14;
  pg.blendMode(ADD);
  pg.noStroke();
  pg.textureMode(NORMAL);
  for (int i = 0; i < cols; i++) for (int j = 0; j < rows; j++) {
    float u0 = f.w * i / cols, u1 = f.w * (i + 1) / cols, v0 = f.h * j / rows, v1 = f.h * (j + 1) / rows;
    float d = dist((u0 + u1) / 2, (v0 + v1) / 2, cx, cy);
    float a = exp(-sq((d - R) / w)) * k;
    if (a < 0.01) continue;
    pg.beginShape(QUADS);
    pg.texture(G);
    pg.tint(hexColor(WARM_LIGHT_COLOR), 100 * min(1, a));
    pg.vertex(u0, v0, u0 / f.w, v0 / f.h); pg.vertex(u1, v0, u1 / f.w, v0 / f.h);
    pg.vertex(u1, v1, u1 / f.w, v1 / f.h); pg.vertex(u0, v1, u0 / f.w, v1 / f.h);
    pg.endShape();
  }
  pg.noTint();
  pg.blendMode(BLEND);
}

// A word written on a wall, in the poem's typeface, over a soft blurred shadow so it reads over anything
PFont poemFont;   // the typeface of the words on the walls and the floor (TEXT_FONT)
PImage wordShadow;            // the shadow of the word on the wall: the word in black, blurred (made once per word)
String wordShadowOf = null;

// (JAVA2D, on the CPU: it may be made while a wall is being drawn — never another OpenGL drawing there)
PImage wordShadowImage(String w) {
  if (w.equals(wordShadowOf) && wordShadow != null) return wordShadow;
  PGraphics g = createGraphics(10, 10, JAVA2D);
  g.beginDraw(); g.textFont(poemFont); g.textSize(96); float tw = g.textWidth(w); g.endDraw();
  int pad = 48;
  g = createGraphics(ceil(tw) + 2 * pad, 96 * 2 + 2 * pad, JAVA2D);
  g.beginDraw();
  g.clear();
  g.textFont(poemFont);
  g.textSize(96);
  g.textAlign(CENTER, CENTER);
  g.fill(0);
  g.text(w, g.width / 2.0, g.height / 2.0);
  g.filter(BLUR, 10);
  g.filter(BLUR, 10);
  g.endDraw();
  wordShadow = g.get();
  wordShadowOf = w;
  return wordShadow;
}

// Its letters are made at the size they are seen at (in output pixels, at the full size of the big word):
// a font made smaller and enlarged comes out soft. One size only (OpenGL keeps a texture per size).
PFont labelFont;
float labelPx;
void drawWordLabel(PGraphics pg, String w, float x, float y, float size, float alpha) {
  if (poemFont == null) poemFont = createFont(TEXT_FONT, 96);
  if (labelFont == null) { labelPx = max(48, ceil(faces[W3].h * WORD_REVEAL_SIZE * RENDER_SCALE)); labelFont = createFont(TEXT_FONT, labelPx); }
  float P = labelPx;
  pg.pushMatrix();
  pg.translate(x, y);
  pg.textFont(labelFont);
  pg.textAlign(CENTER, CENTER);
  pg.textSize(P);                  // always the same size: scaled (down, never up) to the size wanted
  pg.scale(size / P);
  float ta = 100 * alpha;
  PImage sh = wordShadowImage(w);  // (made at 96: drawn at this scale)
  float k = P / 96;
  pg.imageMode(CENTER);
  pg.tint(hexColor(WORD_HALO_COLOR), ta * 0.9);
  pg.image(sh, 0, P * 0.04, sh.width * k, sh.height * k);   // a little below: lifted off the wall
  pg.image(sh, 0, P * 0.04, sh.width * k, sh.height * k);   // (twice: dense enough under the letters, still soft at its edge)
  pg.noTint();
  pg.imageMode(CORNER);
  pg.fill(hexColor(TYPED_WORD_COLOR), ta);
  pg.text(w, 0, 0);
  pg.popMatrix();
}

// ── A special word (rare or very Catalan): announced on WALL 3 ──

String specialBadge(int raresa, int cult) {
  boolean ra = raresa >= SPECIAL_MIN, cu = cult >= SPECIAL_MIN;
  if (ra && cu) return MSG_RARE_CATALAN;
  if (ra) return MSG_RARE;
  if (cu) return MSG_CATALAN;
  return "";
}

// ── The light sweeping over the mural ──
// Every mural wall keeps a gloss image (Ceramic.pde: glaze, gold and glass shine, the mortar
// doesn't); a soft diagonal band of light travels over WALL 4 → WALL 1 → WALL 2 now and then.

PGraphics[] glossLayers = new PGraphics[5];
int celebrateStart = -99999;
boolean restoringMural = false;

// where a wall starts along the sweep (WALL 4, then WALL 1, then WALL 2)
float sweepStart(int face) {
  if (face == W4) return 0;
  if (face == W1) return ROOM_W;
  if (face == W2) return ROOM_W + ROOM_D;
  return -1;
}

void drawSweep(PGraphics pg, Face f) {
  PGraphics G = glossLayers[f.id];
  if (G == null) return;
  float total = 2 * ROOM_W + ROOM_D, band = WALL_H * 0.55;
  float celeb = frameCount - celebrateStart;
  boolean celebrating = celeb >= 0 && celeb < CELEBRATE_FRAMES;
  float period = celebrating ? 160 : SWEEP_FRAMES + SWEEP_PAUSE;
  float travel = celebrating ? 160 : SWEEP_FRAMES;
  float ph = (frameCount % period) / travel;
  float strength = celebrating ? 1.0 : MURAL_SHEEN;
  float glow = celebrating ? 0.45 * pow(sin(PI * celeb / CELEBRATE_FRAMES), 2) : 0;   // the whole mural glows
  if (strength <= 0 && glow <= 0) return;
  float pos = lerp(-band * 2, total + band * 2, ph);
  float x0 = sweepStart(f.id);
  int cols = 64, rows = 4;
  pg.blendMode(ADD);
  pg.noStroke();
  pg.textureMode(NORMAL);
  for (int i = 0; i < cols; i++) for (int j = 0; j < rows; j++) {
    float u0 = f.w * i / cols, u1 = f.w * (i + 1) / cols, v0 = f.h * j / rows, v1 = f.h * (j + 1) / rows;
    float xc = x0 + (u0 + u1) / 2 + ((v0 + v1) / 2 - f.h / 2) * 0.55;   // a diagonal band
    float a = (ph < 1 ? exp(-sq((xc - pos) / band)) * strength : 0) + glow;
    if (a < 0.01) continue;
    pg.beginShape(QUADS);
    pg.texture(G);
    pg.tint(42, 22, 100, 100 * min(1, a));
    pg.vertex(u0, v0, u0 / f.w, v0 / f.h); pg.vertex(u1, v0, u1 / f.w, v0 / f.h);
    pg.vertex(u1, v1, u1 / f.w, v1 / f.h); pg.vertex(u0, v1, u0 / f.w, v1 / f.h);
    pg.endShape();
  }
  pg.noTint();
  pg.blendMode(BLEND);
}

// The mural is full: it glows, a chord, and a new layer begins over the oldest tiles
void startCelebration() {
  if (restoringMural) return;
  celebrateStart = frameCount;
  println("The mural is full: celebration, a new layer begins");
  if (midi != null && soundReady) playWord(7, 1, 4, 7, 4, 1, 7);
}
