// ═══════════════════════════════════════════════════════════
// FloorEcho.pde — PROTOTYPES (FLOOR_ECHO in Config.pde; 0 = the v4 floor)
// "The echo of the trencadís": the floor becomes a dark glaze reflecting the mural.
//   1 A  soft reflections, blurred colour of the walls fading towards the centre
//   2 B  the floor broken into big shards, each reflecting the walls at its own angle
//   3 C  almost black; the reflections wake up only where a word's wave passes
// When a tile settles, a wave in its colour starts at the foot of its wall and crosses
// the floor bending the reflections. Every 60–90 s, when nobody is interacting, the
// floor darkens and one verse of Espriu appears, big, for ~9 s.
// Shader: data/floor_echo.glsl.
// ═══════════════════════════════════════════════════════════

PShader echoShader;
PGraphics wordLayer;   // the visitors' words, drawn for the shader to set them into the glaze
PGraphics echoDummy;
PGraphics[] wallSmall = new PGraphics[5];
ArrayList<float[]> echoWaves = new ArrayList<float[]>();   // { x, y, start, r, g, b }
String[] echoLines;
int echoLine = 0, echoVerseStart = -99999, echoNextVerse = -1;
String echoCurrent = "";
float echoVX, echoVY, echoVA;   // where the current verse is, and its slight tilt

boolean echoOn() { return FLOOR_ECHO > 0 && HAS_FLOOR; }

void updateFloorEcho() {
  if (!echoOn()) return;
  if (echoLines == null) {
    try { echoLines = loadJSONObject("poem_words.json").getString("text", "").split("\n"); } catch (Exception e) { echoLines = new String[0]; }
    echoNextVerse = frameCount + ECHO_VERSE_FIRST;
    seedEchoRegister();
  }
  // soft walls: small copies of the mural, refreshed now and then (A and C)
  if (FLOOR_ECHO != 2 && frameCount % 30 == 1) for (int w : new int[] { W1, W2, W4 }) {
    if (mosaicLayers[w] == null) continue;
    if (wallSmall[w] == null) wallSmall[w] = createGraphics(ECHO_SOFT_PX, max(4, round(ECHO_SOFT_PX * faces[w].h / faces[w].w)), P2D);
    wallSmall[w].beginDraw(); wallSmall[w].clear(); wallSmall[w].image(mosaicLayers[w], 0, 0, wallSmall[w].width, wallSmall[w].height);
    if (ECHO_PREBLUR > 0) wallSmall[w].filter(BLUR, ECHO_PREBLUR);   // optional extra softness
    wallSmall[w].endDraw();
  }
  if (ECHO_WORDS_DRIFT) driftEchoWords();
  if (ECHO_WORDS_IN_GLAZE && ECHO_REVEAL_STYLE) renderWordLayer();
  for (int i = echoWaves.size() - 1; i >= 0; i--) if (frameCount - echoWaves.get(i)[2] > ECHO_WAVE_FRAMES) echoWaves.remove(i);
  // a verse now and then, only in calm
  if (echoLines.length > 0 && frameCount >= echoNextVerse && interactK < 0.1 && frameCount - echoVerseStart > echoVerseLife()) {
    echoVerseStart = frameCount;
    placeEchoVerse();
    echoCurrent = echoLines[echoLine % echoLines.length].trim();   // the poem's lines, in order
    echoLine++;
    echoNextVerse = frameCount + echoVerseLife() + ECHO_VERSE_GAP;   // one after another, a short silence between them
  }
}

int echoVerseLife() { return ECHO_VERSE_IN + ECHO_VERSE_STAY + ECHO_VERSE_OUT; }

// A tile has settled: a wave in its colour from the foot of its wall (Moments.pde)
void echoImpact(TrencadisTile t, int col) { echoImpact(t, col, ""); }

void echoImpact(TrencadisTile t, int col, String word) {
  if (!echoOn()) return;
  float x, y, u = t.origin.x;
  if (t.face == W1)      { x = 0;      y = ROOM_D - u; }
  else if (t.face == W2) { x = u;      y = 0; }
  else if (t.face == W4) { x = ROOM_W - u; y = ROOM_D; }
  else return;
  echoWaveAt(x, y, col);
  if (word.length() > 0 && TYPED_WORDS_TO_FLOOR) {   // its echo on the floor, a little into the room from its wall
    float k = ECHO_WORD_INSET;
    addEchoWord(word, lerp(x, ROOM_W / 2, k), lerp(y, ROOM_D / 2, k));
  }
}

void echoWaveAt(float x, float y, int col) {
  float[] c = { ((col >> 16) & 255) / 255.0, ((col >> 8) & 255) / 255.0, (col & 255) / 255.0 };
  echoWaves.add(new float[] { x, y, frameCount, c[0], c[1], c[2] });
}

// ── The visitors' words: a brief golden echo from a small opening, then a faint memory ──
class EchoWord { String w; float x, y; int t0; float vx, vy, seed, ang; int gone = -1; }
ArrayList<EchoWord> echoWords = new ArrayList<EchoWord>();

void addEchoWord(String w, float x, float y) {
  EchoWord e = new EchoWord();
  e.w = w; e.x = constrain(x, ROOM_W * 0.18, ROOM_W * 0.82); e.y = constrain(y, ROOM_D * 0.15, ROOM_D * 0.85);
  e.t0 = frameCount + ECHO_WORD_DELAY;
  e.seed = random(1000);
  echoWords.add(e);
  if (ECHO_WORDS_DRIFT) {   // too many on the floor: the oldest fades away
    int alive = 0;
    for (EchoWord o : echoWords) if (o.gone < 0) alive++;
    for (EchoWord o : echoWords) if (alive > ECHO_WORDS_KEEP && o.gone < 0) { o.gone = frameCount; alive--; }
  } else while (echoWords.size() > ECHO_MEMORY + 1) echoWords.remove(0);
}

// 0 … 1 bright echo, then ECHO_MEMORY_ALPHA for the most recent ones, then gone
float echoWordAlpha(EchoWord e, int rankFromNewest) {
  float t = frameCount - e.t0;
  if (t < 0) return 0;
  float a = smooth01(t / (float) ECHO_WORD_IN);
  float fade = smooth01((t - ECHO_WORD_IN - ECHO_WORD_STAY) / (float) ECHO_WORD_OUT);
  float mem = (rankFromNewest < ECHO_MEMORY) ? ECHO_MEMORY_ALPHA * (1 - smooth01((t - ECHO_WORD_IN - ECHO_WORD_STAY - ECHO_WORD_OUT) / (float) ECHO_MEMORY_FRAMES)) : 0;
  return a * lerp(1, mem, fade);
}

float echoWordOpen(EchoWord e) {   // its little opening: opens just before the word, closes as the echo fades
  float t = frameCount - e.t0 + 40;
  return smooth01(t / 80.0) * (1 - smooth01((t - 40 - ECHO_WORD_IN - ECHO_WORD_STAY) / (float) ECHO_WORD_OUT));
}

float echoDim() {
  float t = frameCount - echoVerseStart;
  if (t < 0 || t > echoVerseLife()) return 0;
  return smooth01(t / (float) ECHO_VERSE_IN) * (1 - smooth01((t - ECHO_VERSE_IN - ECHO_VERSE_STAY) / (float) ECHO_VERSE_OUT));   // the window and the dimming
}

void drawFloorEcho(PGraphics pg, Face f) {
  if (!echoOn() || f.id != FLOOR) return;
  if (echoShader == null) echoShader = loadShader("floor_echo.glsl");
  if (echoDummy == null) { echoDummy = createGraphics(4, 4, P2D); echoDummy.beginDraw(); echoDummy.background(0); echoDummy.endDraw(); }
  PShader sh = echoShader;
  PGraphics[] src = new PGraphics[5];
  for (int w : new int[] { W1, W2, W4 }) src[w] = (FLOOR_ECHO == 2) ? mosaicLayers[w] : wallSmall[w];
  if (src[W1] == null) return;
  sh.set("w1", src[W1]);
  sh.set("w2", src[W2] != null ? src[W2] : src[W1]);
  sh.set("w4", src[W4] != null ? src[W4] : src[W1]);
  sh.set("room", ROOM_W, ROOM_D, WALL_H);
  sh.set("flipY", 1.0);
  sh.set("flipTex", 1.0);
  sh.set("mode", (float) FLOOR_ECHO);
  float[] str = { 0, ECHO_A_STRENGTH, ECHO_B_STRENGTH, ECHO_C_STRENGTH };
  sh.set("strength", str[FLOOR_ECHO]);
  sh.set("reach", ECHO_REACH);
  sh.set("warp", ECHO_WARP);
  sh.set("time", frameCount / 60.0);
  sh.set("cell", ECHO_CELL);
  sh.set("dimK", echoDim());
  sh.set("stretch", ECHO_STRETCH);
  float[] O = new float[8], OK = new float[2];
  float side = min(ROOM_W, ROOM_D);
  float va = echoDim();
  O[0] = echoVX; O[1] = echoVY; O[2] = side * ECHO_OPEN_W; O[3] = side * ECHO_OPEN_H;   // the verse's window (its long side along y)
  OK[0] = va;
  EchoWord last = echoWords.size() > 0 ? echoWords.get(echoWords.size() - 1) : null;
  if (last != null) {
    O[4] = last.x; O[5] = last.y;
    if (ECHO_REVEAL_STYLE) { O[6] = side * 0.09; O[7] = side * 0.16; OK[1] = echoWordLight(last); }
    else { O[6] = side * 0.07; O[7] = side * 0.2; OK[1] = echoWordOpen(last) * 0.85; }
  }
  if (ECHO_REVEAL_STYLE) { O[2] = side * ECHO_CALM_W; O[3] = side * ECHO_CALM_H; }
  sh.set("revealStyle", ECHO_REVEAL_STYLE ? 1.0 : 0.0);
  sh.set("calmDim", ECHO_CALM_DIM);
  sh.set("wordGlow", ECHO_WORD_GLOW);
  float[] WP = new float[30];
  int nw = 0;
  for (EchoWord e : echoWords) {
    if (nw >= 10) break;
    float t = frameCount - e.t0;
    if (t < 0) continue;
    float st = smooth01(t / 120.0) * (e.gone >= 0 ? 1 - smooth01((frameCount - e.gone) / 300.0) : 1);
    WP[nw * 3] = e.x; WP[nw * 3 + 1] = e.y; WP[nw * 3 + 2] = st;
    nw++;
  }
  sh.set("wordPts", WP, 3);
  sh.set("nWordPts", (float) nw);
  sh.set("wordRipple", ECHO_WORD_RIPPLE);
  sh.set("openings", O, 4);
  sh.set("openK", OK);
  float[] rc = rgb01(WARM_LIGHT_COLOR);
  sh.set("rimCol", rc[0], rc[1], rc[2]);
  sh.set("blur", FLOOR_ECHO == 2 ? 0.0 : ECHO_BLUR);
  float[] Wv = new float[16], C = new float[12];
  int n = 0;
  float boost = (FLOOR_ECHO == 3) ? ECHO_C_WAVE : 1;
  for (float[] w : echoWaves) {
    if (n >= 4) break;
    float t = (frameCount - w[2]) / (float) ECHO_WAVE_FRAMES;
    Wv[n * 4] = w[0]; Wv[n * 4 + 1] = w[1];
    Wv[n * 4 + 2] = ECHO_WAVE_REACH * (0.2 * (1 - pow(1 - t, 3)) + 0.8 * t);
    Wv[n * 4 + 3] = ECHO_WAVE * boost * pow(1 - t, 1.4) * smooth01(t / 0.04);
    C[n * 3] = w[3]; C[n * 3 + 1] = w[4]; C[n * 3 + 2] = w[5];
    n++;
  }
  sh.set("nWaves", (float) n);
  sh.set("waves", Wv, 4);
  sh.set("waveCols", C, 3);
  sh.set("waveWidth", ECHO_WAVE_WIDTH);
  boolean glaze = ECHO_WORDS_IN_GLAZE && ECHO_REVEAL_STYLE;
  if (glaze && wordLayer != null) {
    sh.set("wordsTex", wordLayer);
  }
  sh.set("wordsOn", glaze ? 1.0 : 0.0);
  float[] am = rgb01(TYPED_NEW_COLOR), wl = rgb01(WARM_LIGHT_COLOR);
  sh.set("amber", am[0], am[1], am[2]);
  sh.set("bright", wl[0], wl[1], wl[2]);
  sh.set("wordLight", ECHO_GLAZE_LIGHT);
  pg.shader(sh);
  pg.image(echoDummy, 0, 0, f.w, f.h);
  pg.resetShader();
  drawEchoVerse(pg, f);
  if (!(ECHO_WORDS_IN_GLAZE && ECHO_REVEAL_STYLE)) drawEchoWords(pg, f);
}

// One verse, big, in the middle of the floor, read facing the main wall; fades in and out in place
void drawEchoVerse(PGraphics pg, Face f) {
  float t = frameCount - echoVerseStart;
  if (t < 0 || t > echoVerseLife() || echoCurrent.length() == 0) return;
  // revealStyle: latent under the surface — first a faint typographic haze, then it gathers into
  // clear letters; at the end it loosens back into haze and sinks into the floor. No movement.
  float a, haze;
  if (ECHO_REVEAL_STYLE) {
    float in = smooth01((t - ECHO_VERSE_IN * 0.3) / (ECHO_VERSE_IN * 1.0));
    float out = smooth01((t - ECHO_VERSE_IN - ECHO_VERSE_STAY) / (float) ECHO_VERSE_OUT);
    a = in * (1 - out) * ECHO_VERSE_ALPHA / 100.0;
    haze = max(1 - smooth01((t - ECHO_VERSE_IN * 0.3) / (ECHO_VERSE_IN * 1.3)), out);
  } else {
    a = smooth01((t - ECHO_VERSE_IN * 0.45) / (ECHO_VERSE_IN * 0.8)) * (1 - smooth01((t - ECHO_VERSE_IN - ECHO_VERSE_STAY) / (ECHO_VERSE_OUT * 0.7)));
    haze = 0;
  }
  if (a < 0.003) return;
  String line = echoCurrent;
  if (poemFont == null) poemFont = createFont(TEXT_FONT, 96);
  pg.pushMatrix();
  pg.translate(echoVX, echoVY);
  pg.rotate((ECHO_VERSE_FACING_MURAL ? -HALF_PI : HALF_PI) + echoVA);   // read standing in the room facing the mural, a slight tilt of its own
  pg.textFont(poemFont);
  pg.textSize(96);
  float em = min(f.w, f.h) * ECHO_VERSE_EM;
  String[] lines = splitVerse(line);
  float tw = 0;
  for (String l : lines) tw = max(tw, pg.textWidth(l) * em / 96);
  if (tw > f.h * 0.6) em *= f.h * 0.6 / tw;
  pg.scale(em / 96);
  pg.textAlign(CENTER, CENTER);
  int c = hexColor(VERSE_COLOR);
  if (haze > 0.01) {   // the haze: soft copies spread around the letters, converging as it clears
    float rad = 96 * ECHO_VERSE_FOG * haze;
    for (int k = 0; k < 10; k++) {
      float an = TWO_PI * k / 10 + 0.3;
      pg.fill(c, 100 * a * 0.13);
      for (int li = 0; li < lines.length; li++) pg.text(lines[li], cos(an) * rad, sin(an) * rad * 0.6 + lineY(li, lines.length));
    }
  }
  pg.fill(c, 100 * a * (1 - 0.85 * haze));
  for (int li = 0; li < lines.length; li++) pg.text(lines[li], 0, lineY(li, lines.length));
  pg.popMatrix();
}

// The light gathering where a visitor's word is about to be written, then easing off with it
float echoWordLight(EchoWord e) {
  float t = frameCount - e.t0 + ECHO_WORD_LEAD;
  return smooth01(t / (float) ECHO_WORD_LEAD) * (1 - smooth01((t - ECHO_WORD_LEAD - wordWriteFrames(e) - ECHO_WORD_STAY) / (float) ECHO_WORD_OUT)) * 0.9
       + 0.0;
}

int wordWriteFrames(EchoWord e) { return e.w.length() * ECHO_WORD_WRITE + ECHO_WORD_IN; }

void drawEchoWords(PGraphics pg, Face f) { drawEchoWords(pg, f, false); }

// glaze: drawn into wordLayer (RGB, alpha 0–255): G, B = 1, R = how freshly written, A = coverage;
// the floor shader then sets them into the glaze (lit by the reflection, warped with it)
void drawEchoWords(PGraphics pg, Face f, boolean glaze) {
  if (poemFont == null) poemFont = createFont(TEXT_FONT, 96);
  float side = min(f.w, f.h);
  float aK = glaze ? 2.55 : 1;
  for (int i = 0; i < echoWords.size(); i++) {
    EchoWord e = echoWords.get(i);
    int rank = echoWords.size() - 1 - i;
    float t = frameCount - e.t0;
    if (t < 0) continue;
    pg.pushMatrix();
    pg.translate(e.x, e.y);
    pg.rotate((ECHO_VERSE_FACING_MURAL ? -HALF_PI : HALF_PI) + e.ang);
    pg.textFont(poemFont);
    pg.textSize(96);
    pg.scale(side * ECHO_WORD_EM / 96);
    pg.textAlign(LEFT, CENTER);
    if (!ECHO_REVEAL_STYLE) {
      float a = echoWordAlpha(e, rank);
      pg.textAlign(CENTER, CENTER);
      pg.fill(hexColor(TYPED_NEW_COLOR), 100 * a);
      if (a > 0.003) pg.text(e.w, 0, 0);
      pg.popMatrix();
      continue;
    }
    // written in light, letter by letter: each letter appears bright and settles to amber
    float life = wordWriteFrames(e) + ECHO_WORD_STAY;
    float fade = smooth01((t - life) / (float) ECHO_WORD_OUT);
    float mem = ECHO_WORDS_DRIFT ? ECHO_DRIFT_ALPHA * (e.gone >= 0 ? 1 - smooth01((frameCount - e.gone) / 300.0) : 1) * echoAgeFade(e, t - life - ECHO_WORD_OUT)
              : (rank < ECHO_MEMORY) ? ECHO_MEMORY_ALPHA * (1 - smooth01((t - life - ECHO_WORD_OUT) / (float) ECHO_MEMORY_FRAMES)) : 0;
    float keep = lerp(1, glaze ? min(1, mem * ECHO_GLAZE_KEEP) : mem, fade);
    if (keep < 0.003) { pg.popMatrix(); continue; }
    float x = -pg.textWidth(e.w) / 2;
    int amber = hexColor(TYPED_NEW_COLOR), bright = hexColor(WARM_LIGHT_COLOR);
    float sink = glaze ? 1 - echoAgeFade(e, t - life - ECHO_WORD_OUT) : 0;   // older: sinking under the glaze, softer
    for (int k = 0; k < e.w.length(); k++) {
      String ch = e.w.substring(k, k + 1);
      float tk = t - k * ECHO_WORD_WRITE;
      float a = smooth01(tk / (float) ECHO_WORD_IN) * keep;
      float hot = 1 - smooth01((tk - ECHO_WORD_IN * 0.4) / (ECHO_WORD_IN * 1.6));   // the freshly written letter glows
      if (a > 0.003 && glaze) {
        int code = 0xFF00FFFF | (round(255 * hot) << 16);
        float soft = 96 * (ECHO_GLAZE_SOFT + ECHO_GLAZE_SINK * sink);
        for (int q = 0; q < 6; q++) {   // a soft edge, wider as it sinks
          float an = TWO_PI * q / 6 + 0.5;
          pg.fill(code, aK * 100 * a * 0.14);
          pg.text(ch, x + cos(an) * soft, sin(an) * soft);
        }
        pg.fill(code, aK * 100 * a * (1 - 0.55 * sink) * ECHO_WORD_ALPHA / 100.0);
        pg.text(ch, x, 0);
      } else if (a > 0.003) {
        if (hot > 0.02) { pg.fill(bright, 100 * a * 0.25 * hot); pg.text(ch, x - 2, 0); pg.text(ch, x + 2, 0); }
        pg.fill(mixRGB(amber, bright, 0.6 * hot), 100 * a * ECHO_WORD_ALPHA / 100.0);
        pg.text(ch, x, 0);
      }
      x += pg.textWidth(ch);
    }
    pg.popMatrix();
  }
}

// After it is written, a visitor's word stays on the floor and drifts slowly, in long gentle curves,
// always reading the same way; it keeps its distance from the others and from the verse's place
void driftEchoWords() {
  float side = min(ROOM_W, ROOM_D);
  for (int i = echoWords.size() - 1; i >= 0; i--) {
    EchoWord e = echoWords.get(i);
    if (e.gone >= 0 && frameCount - e.gone > 300) { echoWords.remove(i); continue; }
    if (frameCount - e.t0 > echoWordLifeFrames(e)) { echoWords.remove(i); continue; }   // its time on the floor is over
    float t = frameCount - e.t0 - wordWriteFrames(e) - ECHO_WORD_STAY;
    if (t < 0) continue;
    float k = smooth01(t / 600.0);                          // eases into motion
    float a = noise(e.seed, frameCount * 0.0007) * TWO_PI * 2;
    float wx = cos(a), wy = sin(a);
    for (EchoWord o : echoWords) {                         // a little room between them
      if (o == e) continue;
      float dx = e.x - o.x, dy = e.y - o.y, d = sqrt(dx * dx + dy * dy), room = side * ECHO_DRIFT_ROOM;
      if (d < room && d > 1) { wx += dx / d * (1 - d / room) * 2; wy += dy / d * (1 - d / room) * 2; }
    }
    if (echoDim() > 0.01) {                                 // the verse's place stays clear while it is shown
      float dx = e.x - echoVX, dy = e.y - echoVY, d = sqrt(dx * dx + dy * dy), room = side * ECHO_CALM_H;
      if (d < room && d > 1) { wx += dx / d * 2 * (1 - d / room); wy += dy / d * 2 * (1 - d / room); }
    }
    e.ang = ECHO_WORD_TURN * (noise(e.seed + 50, frameCount * 0.0006) - 0.5) * 2 * k;   // turning subtly as it drifts
    float m = 0.12;                                          // and away from the edges
    if (e.x < ROOM_W * m) wx += 1; if (e.x > ROOM_W * (1 - m)) wx -= 1;
    if (e.y < ROOM_D * m) wy += 1; if (e.y > ROOM_D * (1 - m)) wy -= 1;
    float l = max(0.001, sqrt(wx * wx + wy * wy));
    e.vx = lerp(e.vx, wx / l * ECHO_DRIFT_SPEED * k, 0.01);
    e.vy = lerp(e.vy, wy / l * ECHO_DRIFT_SPEED * k, 0.01);
    e.x += e.vx; e.y += e.vy;
  }
}

// A verse in two lines, cut at the space nearest the middle
String[] splitVerse(String l) {
  if (l.length() < 26) return new String[] { l };
  int mid = l.length() / 2, best = -1;
  for (int i = 0; i < l.length(); i++) if (l.charAt(i) == ' ' && (best < 0 || abs(i - mid) < abs(best - mid))) best = i;
  if (best < 0) return new String[] { l };
  return new String[] { l.substring(0, best).trim(), l.substring(best + 1).trim() };
}

float lineY(int i, int n) { return (i - (n - 1) / 2.0) * 96 * 1.35; }

// Each verse somewhere else on the floor, clear of the drifting words, with a slight tilt
void placeEchoVerse() {
  Random r = new Random(echoLine * 7919L + 11);
  float best = -1;
  for (int k = 0; k < 40; k++) {
    float x = ROOM_W * rnd(r, 0.18, 0.72), y = ROOM_D * rnd(r, 0.28, 0.72);
    float d = Float.MAX_VALUE;
    for (EchoWord e : echoWords) d = min(d, dist(x, y, e.x, e.y));
    d += rnd(r, 0, ROOM_W * 0.08);
    if (d > best) { best = d; echoVX = x; echoVY = y; }
  }
  echoVA = radians(rnd(r, -ECHO_VERSE_TILT, ECHO_VERSE_TILT));
}

// ── The floor's register: the last ECHO_WORDS_KEEP words typed stay on the floor for
// ECHO_WORD_LIFE seconds, more and more transparent as they age, then they are gone ──

int echoWordLifeFrames(EchoWord e) { return wordWriteFrames(e) + ECHO_WORD_STAY + ECHO_WORD_OUT + ECHO_WORD_LIFE * 60; }

// 1 when it has just settled … 0 at the end of its life (eased, so it lingers faintly)
float echoAgeFade(EchoWord e, float tSettled) {
  if (tSettled <= 0) return 1;
  return 1 - smooth01(tSettled / (ECHO_WORD_LIFE * 60f));
}

// On start: the last words typed (saved with the mural) come back to the floor, as old as they really are
void seedEchoRegister() {
  if (!ECHO_WORDS_DRIFT || mosaicTiles == null) return;
  long now = System.currentTimeMillis();
  Random r = new Random(17);
  int n = mosaicTiles.size();
  for (int i = max(0, n - ECHO_WORDS_KEEP); i < n; i++) {
    JSONObject rec = mosaicTiles.getJSONObject(i);
    if (!rec.hasKey("time")) continue;
    float ageS = (now - rec.getLong("time")) / 1000f;
    if (ageS > ECHO_WORD_LIFE) continue;
    addEchoWord(rec.getString("word", ""), ROOM_W * rnd(r, 0.2, 0.85), ROOM_D * rnd(r, 0.15, 0.85));
    EchoWord e = echoWords.get(echoWords.size() - 1);
    e.t0 = frameCount - (wordWriteFrames(e) + ECHO_WORD_STAY + ECHO_WORD_OUT) - round(ageS * 60);
  }
  println("Floor register: " + echoWords.size() + " words back on the floor");
}

// The visitors' words into their own layer, for the floor shader (drawn before the faces)
void renderWordLayer() {
  Face f = faces[FLOOR];
  if (wordLayer == null) wordLayer = createGraphics(ECHO_GLAZE_PX, ECHO_GLAZE_PX, P2D);   // power of two: sampled 1:1 by the shader
  wordLayer.beginDraw();
  wordLayer.clear();
  wordLayer.pushMatrix();
  wordLayer.scale(wordLayer.width / f.w, wordLayer.height / f.h);
  wordLayer.noStroke();
  drawEchoWords(wordLayer, f, true);
  wordLayer.popMatrix();
  wordLayer.endDraw();
}
