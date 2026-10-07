// ═══════════════════════════════════════════════════════════
// Trencadis.pde
// Each word becomes one TILE of a Catalan trencadís mosaic:
// a cell with STRAIGHT edges, broken into straight-edged shards
// set with thin grey grout.
//
// The tile is broken like real ceramic: straight cracks, again and
// again, plus chipped corners → shards of 3 to 7 sides (shatter()).
// Per phenomenon: how regular the shards are and how many keep
// 4 sides (CUT_STYLE). Plain shards use a 6-tone palette from the
// word's colour, with a few white "crockery" shards, and
// neighbouring shards never share a tone.
//
// On top of that, some phenomena first PAINT a decorated tile
// (spiral, flowers, tilework, waves, checker) and the shards cut
// through the motif, each one set slightly off, as in Park Güell.
//
//   phenomena_class → cut style + motif (see CUT_STYLE and paint())
//   color_hex       → palette
//   abstraction     → shard size (abstract = big, simple shards)
//   word_class      → how the shards come in while assembling (entrance())
//   organic         → extra irregularity of the cuts
//
// Every decision comes from a Random seeded with the word and its
// parameters, so the same word always produces the same tile.
// ═══════════════════════════════════════════════════════════

import java.util.Random;

// Per phenomenon 1..7: { share of 4-sided shards (fewer chipped corners), irregularity of the cracks }
float[][] CUT_STYLE = {
  { 0.6, 0.12 },   // 1 static
  { 0.1, 0.30 },   // 2 soft dispersion
  { 0.3, 0.22 },   // 3 spiral deformation
  { 0.5, 0.28 },   // 4 noisy sub-clusters
  { 0.0, 0.26 },   // 5 high-frequency vibration
  { 0.2, 0.32 },   // 6 directional drift
  { 0.4, 0.18 }    // 7 three groupings
};

// Dark ceramic tones of the ribbon along the top edge of each band of
// WALL 1 (one per band), mixed a little with each word's colour. HSB.
float[][] RIBBON_TONES = {
  { 25, 55, 36 },   // brown
  {185, 45, 38 },   // deep teal
  { 30, 12, 22 },   // near black
  { 35, 65, 58 },   // ochre
  {150, 35, 32 },   // bottle green
  {  5, 50, 40 }    // oxblood
};

// Light comes from the upper left (y grows downwards); only used for the soft glaze sheen
final float LIGHT_X = -0.6, LIGHT_Y = -0.8;

// The glazes of Park Güell: nearest one to a hue (violets → indigo, pinks → red)
float[] GLAZE_HUES = { 2, 12, 18, 30, 42, 72, 142, 185, 210 };

float ceramicHue(float h) {
  h = (h % 360 + 360) % 360;
  if (h >= 225 && h < 315) return 210;   // violet / indigo → cobalt (no violet blues)
  if (h >= 315)            return 354;   // pink / magenta → red
  float best = GLAZE_HUES[0];
  for (float g : GLAZE_HUES) if (abs(g - h) < abs(best - h)) best = g;
  return best;
}

// Stable seed (String.hashCode style, same on every run and machine)
long wordSeed(String word, int... params) {
  long h = 1125899906842597L;
  String w = word.trim().toLowerCase();
  for (int i = 0; i < w.length(); i++) h = 31 * h + w.charAt(i);
  for (int p : params) h = 31 * h + p;
  return h;
}

float rnd(Random r, float a, float b) { return a + r.nextFloat() * (b - a); }

float smooth01(float x) {
  x = constrain(x, 0, 1);
  return x * x * (3 - 2 * x);
}

float easeInOutCubic(float x) {
  x = constrain(x, 0, 1);
  return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2;
}

// ********************
//   Patch
// ********************

// A cell with straight edges: a top and a bottom polyline, both left → right.
// Corners are top[0], top[last], bot[last], bot[0].
class Patch {
  PVector[] top, bot;

  Patch(PVector[] top, PVector[] bot) {
    this.top = top;
    this.bot = bot;
  }

  ArrayList<PVector> outline() {
    ArrayList<PVector> p = new ArrayList<PVector>();
    for (PVector q : top) p.add(q.copy());
    for (int i = bot.length - 1; i >= 0; i--) p.add(bot[i].copy());
    return p;
  }

  PVector center() { return polyCenter(outline()); }
}

// A free-standing tile (poem words): an irregular angular hexagon
Patch freePatch(Random r, float w, float h) {
  float j = 0.12;
  PVector[] top = {
    new PVector(-w/2 + rnd(r, -j, j) * w, -h/2 + rnd(r, -j, j) * h),
    new PVector(rnd(r, -0.2, 0.2) * w,    -h/2 + rnd(r, -0.2, 0.05) * h),
    new PVector( w/2 + rnd(r, -j, j) * w, -h/2 + rnd(r, -j, j) * h) };
  PVector[] bot = {
    new PVector(-w/2 + rnd(r, -j, j) * w,  h/2 + rnd(r, -j, j) * h),
    new PVector(rnd(r, -0.2, 0.2) * w,     h/2 + rnd(r, -0.05, 0.2) * h),
    new PVector( w/2 + rnd(r, -j, j) * w,  h/2 + rnd(r, -j, j) * h) };
  return new Patch(top, bot);
}

// ********************
//   Tile
// ********************

class Piece {
  float[] x, y;        // tile-local outline, already inside the grout
  float[] u, v;        // texture coordinates (null = plain colour)
  float[] grad;        // per-vertex: where each corner lies along the tilt (−1 shaded side … 1 lit side)
  float[] rx, ry;      // inner edge of the rounded rim (null = too small for a rim)
  float[] rimLit;      // per edge: how much it faces the light (−1 … 1)
  boolean[] chipped;   // per edge: glaze chipped off, the pale biscuit shows
  float lit;           // how much the shard's tilted face catches the light (−1 … 1)
  float spec;          // strength of the glaze highlight on this shard (0 … 1)
  float h, s, b;       // plain colour; for painted shards only b is used (glaze tint)
  float cx, cy, area;
  float delay;         // assembly: when it settles (0..1)
  float fx, fy, fz, frot;   // assembly: where it comes in from (offset, lift, turn)
  float fs;                 // assembly: starting scale
}

class TrencadisTile {
  long seed;
  Patch patch;
  PVector origin;                 // centre of the cell = the tile's (0,0)
  float[] gx, gy;                 // grout bed = the whole cell
  ArrayList<Piece> pieces = new ArrayList<Piece>();
  float radius, tileW, tileH;
  PImage tex;                     // the painted tile before breaking (null = plain shards)

  // Generation only (cell coordinates, before moving the origin to the centre)
  Random r;
  float X0, Y0, W, H, rib, CH;    // bounding box of the cell, ribbon thickness, content height
  float u, jit, quadProb;         // shard size, mesh jitter, share of quads
  int phen, wc;
  float[][] tones;                // plain palettes (index 5 = white crockery)

  TrencadisTile(long seed, color col, int abstraction, int organic, int phenomenon, int wordClass, Patch patch, int band) {
    this.seed  = seed;
    this.patch = patch;
    r      = new Random(seed);
    phen   = constrain(phenomenon, 1, 7);
    wc     = constrain(wordClass, 1, 8);
    origin = patch.center();

    ArrayList<PVector> outline = patch.outline();
    float x1 = -Float.MAX_VALUE, y1 = -Float.MAX_VALUE;
    X0 = Float.MAX_VALUE;
    Y0 = Float.MAX_VALUE;
    for (PVector q : outline) { X0 = min(X0, q.x); Y0 = min(Y0, q.y); x1 = max(x1, q.x); y1 = max(y1, q.y); }
    W = x1 - X0;
    H = y1 - Y0;
    float cellH = (patch.bot[0].y - patch.top[0].y + patch.bot[patch.bot.length-1].y - patch.top[patch.top.length-1].y) / 2;
    rib = (band >= 0) ? cellH * 0.13 : 0;
    CH  = H - rib;
    u   = (cellH - rib) * map(abstraction, 1, 7, 0.19, 0.34);
    quadProb = CUT_STYLE[phen - 1][0];
    jit      = CUT_STYLE[phen - 1][1] * map(organic, 1, 7, 0.7, 1.3);

    makePalette(col, band);
    tex = paint();

    ArrayList<PVector> content = outline;
    if (rib > 0) content = ribbon();
    shatter(content);
    makeBed(outline);
    orderAssembly();
    r = null;
  }

  // ── Palette: ceramic glazes, never neon ──────────────────

  float[] cBase, cLight, cDark, cAcc, cAcc2, cRib;

  void makePalette(color col, int band) {
    // Strong ceramic glazes as on Park Güell: the word's colour is moved to the nearest glaze
    // (cobalt, navy, turquoise, deep green, olive, ochre, orange, red); violets and pinks go to
    // indigo and red. Never pastel.
    float h0 = ceramicHue(hue(col));
    boolean warm = (h0 < 60 || h0 > 330);
    float s0 = constrain(saturation(col) * 1.2, 72, 92);
    float b0 = constrain(brightness(col), 58, 88);
    if (h0 >= 200 && h0 <= 240) b0 = min(b0, 72);   // blues are deep
    if (h0 >= 130 && h0 <= 160) { s0 = max(s0, 85); b0 = constrain(b0, 38, 52); }   // greens: bottle green
    if (h0 >= 8 && h0 <= 16)    { s0 = max(s0, 80); b0 = constrain(b0, 50, 64); }   // terracotta
    cBase  = new float[] { h0, s0, b0 };
    cLight = new float[] { 42, 7, 96 };                                   // the white / cream of the tiles
    cDark  = new float[] { lerpAngle(h0, 225, 0.7), 60, 18 };             // near-black navy outlines
    // Accent from the other family: cobalt against warm colours, orange / ochre against cool ones
    float q = r.nextFloat();
    float hA = warm ? (q < 0.65 ? 218 : 190) : (q < 0.6 ? 28 : 8);
    hA = (hA + rnd(r, -6, 6) + 360) % 360;
    cAcc  = new float[] { hA, rnd(r, 80, 92), (hA > 180 && hA < 240) ? rnd(r, 58, 70) : rnd(r, 82, 92) };
    cAcc2 = (abs(h0 - 42) < 15) ? new float[] { 4, 82, 72 }                // ochre base → red
                                : new float[] { 42, 85, 90 };              // otherwise ochre / saffron
    if (band >= 0) {
      float[] t = RIBBON_TONES[band % RIBBON_TONES.length];
      cRib = new float[] { lerpAngle(t[0], h0, 0.2), t[1], t[2] };
    } else {
      cRib = new float[] { h0, min(90, s0 + 5), b0 * 0.45 };
    }

    float[] white = { 42, 6, 95 };   // white crockery
    // One colour family, many strong shades (the blue areas of the benches)
    tones = new float[][] {
      { h0, s0, b0 },
      { (h0 + 8) % 360,   s0 * 0.92,          min(b0 * 1.12, 98) },
      { (h0 + 352) % 360, min(s0 * 1.05, 100), b0 * 0.7 },
      { (h0 + 14) % 360,  s0 * 0.8,           min(b0 + 10, 98) },
      { h0,               min(s0 * 1.05, 100), b0 * 0.48 },
      white };
  }


  // A colour with a little natural variation, as different firings of the same glaze
  float[] vary(float[] c, float dh, float ds, float db) {
    return new float[] { ((c[0] + rnd(r, -dh, dh)) % 360 + 360) % 360,
                         constrain(c[1] + rnd(r, -ds, ds), 0, 100),
                         constrain(c[2] + rnd(r, -db, db), 0, 100) };
  }

  // Tone index avoiding the neighbours' tones; a few white crockery shards
  int pickTone(int... avoid) {
    int k = 0;
    for (int tries = 0; tries < 30; tries++) {
      k = r.nextFloat() < 0.06 ? 5 : r.nextInt(5);
      boolean clash = false;
      for (int a : avoid) clash |= (a == k);
      if (!clash) break;
    }
    return k;
  }

  // ── The painted tile (texture over the cell's bounding box, cell units) ──

  // Atlas (phenomena 1, 2, 4): one texture holds 6 different source tiles (3 × 2 cells);
  // every shard takes its picture from one of them, as real trencadís is made of many tiles.
  final int AC = 3, AR = 2;
  boolean atlas;
  int mapCell;                     // for the shard being added: which source tile, where, how turned
  float mapX, mapY, mapRot;
  float cellUnits;                 // size of one source tile, in tile units

  PImage paint() {
    atlas = (phen <= 4);
    if (atlas) {
      cellUnits = u * (phen == 2 ? 2.6 : phen == 1 ? 1.9 : 3.2);
      int CS = constrain(round(cellUnits * RENDER_SCALE * TEXTURE_DETAIL), 48, 512);
      PGraphics g = createGraphics(AC * CS, AR * CS, JAVA2D);
      g.beginDraw();
      g.colorMode(HSB, 360, 100, 100, 100);
      int[] order = { 0, 1, 2, 3, 4, 5 };
      for (int i = 5; i > 0; i--) { int j = r.nextInt(i + 1), t = order[i]; order[i] = order[j]; order[j] = t; }
      for (int k = 0; k < AC * AR; k++) {
        g.pushMatrix();
        g.translate((k % AC) * CS, (k / AC) * CS);
        g.clip(0, 0, CS, CS);
        if (phen == 4)      paintSource(g, order[k], k, CS);
        else if (phen == 3) { if (k < 4) paintRosette(g, k, CS); else paintPlain(g, tones[k == 4 ? 0 : 2], CS); }
        else if (phen == 1) paintModernista(g, k, CS);
        else                paintPlain(g, tones[k], CS);
        glazeDetail(g, CS, CS, CS / 40.0);
        g.noClip();
        g.popMatrix();
      }
      g.endDraw();
      return g.get();
    }
    // Enough pixels for the biggest size it is shown at (on the main wall), never more than needed
    int TW = constrain(round(W * RENDER_SCALE * TEXTURE_DETAIL), 128, 1400), TH = max(16, round(TW * H / W));
    PGraphics g = createGraphics(TW, TH, JAVA2D);
    g.beginDraw();
    g.colorMode(HSB, 360, 100, 100, 100);
    g.scale(TW / W);
    switch (phen) {
      case 5:  paintStars(g);    break;   // vibration    → Valencian eight-point stars
      case 6:  paintBands(g);    break;   // drift        → interlaced chains and stripes
      default: paintChecker(g);           // 3 groupings  → bold two-colour geometry
    }
    glazeDetail(g, W, H, u * 0.03);
    g.endDraw();
    return g.get();
  }

  void fillC(PGraphics g, float[] c, float a) { g.fill(c[0], c[1], c[2], a); }
  void strokeC(PGraphics g, float[] c, float a) { g.stroke(c[0], c[1], c[2], a); }

  // Uneven glaze: soft, almost invisible clouds of lighter and darker colour
  void mottle(PGraphics g, float[] c, int n, float amount) {
    g.noStroke();
    for (int i = 0; i < n; i++) {
      fillC(g, vary(c, 6, 8, 14), rnd(r, 0.4, 1) * amount);
      float d = u * rnd(r, 1.5, 4.5);
      g.ellipse(rnd(r, 0, W), rnd(r, 0, H), d, d * rnd(r, 0.6, 1));
    }
  }



  // ── Small glaze imperfections: pinholes, specks and a faint crackle ──
  void glazeDetail(PGraphics g, float w, float h, float dot) {
    g.noStroke();
    int n = round(w * h / sq(dot * 26));
    for (int i = 0; i < n; i++) {
      boolean dark = r.nextFloat() < 0.6;
      g.fill(0, 0, dark ? 10 : 100, dark ? rnd(r, 4, 10) : rnd(r, 8, 18));
      float d = dot * rnd(r, 0.4, 0.9);
      g.ellipse(rnd(r, 0, w), rnd(r, 0, h), d, d);
    }
    g.noFill();
    g.stroke(0, 0, 20, 4);
    g.strokeWeight(dot * 0.5);
    for (int i = 0, m = 3 + r.nextInt(4); i < m; i++) {
      float x = rnd(r, 0, w), y = rnd(r, 0, h), a = rnd(r, 0, TWO_PI);
      g.beginShape();
      for (int j = 0; j < 6; j++) {
        g.vertex(x, y);
        a += rnd(r, -0.6, 0.6);
        float l = dot * rnd(r, 8, 20);
        x += cos(a) * l;
        y += sin(a) * l;
      }
      g.endShape();
    }
    g.noStroke();
  }

  // One plain glazed tile (phenomena 1 and 2): its colour, unevenly fired
  void paintPlain(PGraphics g, float[] c, float s) {
    g.noStroke();
    fillC(g, c, 100);
    g.rect(0, 0, s, s);
    for (int i = 0; i < 9; i++) {
      fillC(g, vary(c, 4, 6, 10), rnd(r, 8, 20));
      float d = s * rnd(r, 0.3, 0.9);
      g.ellipse(rnd(r, 0, s), rnd(r, 0, s), d, d * rnd(r, 0.6, 1));
    }
  }

  // Phenomenon 4: six different decorated tiles, broken and mixed (each shard keeps
  // the picture of the tile it came from). Inspired by the benches of Park Güell.
  void paintSource(PGraphics g, int design, int k, float s) {
    float[][] inks = { cBase, cAcc, cAcc2, cDark };
    // each source tile gets its own two or three colours
    float[] c1 = inks[(k + design) % 4], c2 = inks[(k + design + 1 + r.nextInt(2)) % 4], c3 = cDark;
    if (c2 == c1) c2 = cAcc2;
    float[] ground = vary(cLight, 4, 3, 2);
    g.noStroke();
    fillC(g, ground, 100);
    g.rect(0, 0, s, s);
    float lw = s * 0.018;   // painted outline
    switch (design) {
      case 0: {   // Valencian eight-point star, with quarter stars in the corners
        for (int i = 0; i <= 1; i++) for (int j = 0; j <= 1; j++) star8(g, i * s, j * s, s * 0.32, c2, c3, lw);
        star8(g, s / 2, s / 2, s * 0.34, c1, c3, lw);
        fillC(g, c2, 100);
        diamond(g, s / 2, s / 2, s * 0.06, s * 0.06);
        break;
      }
      case 1: {   // interlaced chain between two bands
        fillC(g, c2, 100);
        g.rect(0, 0, s, s * 0.14);
        g.rect(0, s * 0.86, s, s * 0.14);
        g.noFill();
        g.strokeJoin(MITER);
        for (int pass = 0; pass < 2; pass++) {
          strokeC(g, pass == 0 ? c3 : c1, 100);
          g.strokeWeight(pass == 0 ? s * 0.12 : s * 0.075);
          for (int row = 0; row < 2; row++) {
            float y0 = s * (0.32 + row * 0.36), dy = s * 0.13 * (row == 0 ? 1 : -1);
            g.beginShape();
            for (float x = -s * 0.25; x <= s * 1.25; x += s * 0.25) g.vertex(x, y0 + ((round(x / (s * 0.25)) % 2 == 0) ? -dy : dy));
            g.endShape();
          }
        }
        g.noStroke();
        break;
      }
      case 2: {   // stripes, like the green and white bands
        float y = 0;
        int i = 0;
        while (y < s) {
          float w = s * rnd(r, 0.08, 0.22);
          fillC(g, i % 2 == 0 ? c1 : ground, 100);
          g.rect(0, y, s, w);
          fillC(g, c3, 70);
          g.rect(0, y + w - lw, s, lw);
          y += w;
          i++;
        }
        break;
      }
      case 3: {   // dotted band with fine borders and a scroll
        fillC(g, c2, 100);
        g.rect(0, s * 0.3, s, s * 0.4);
        // fine texture of small lozenges and crosses, a few tones from the band (not a contrast)
        float[] tex2 = { c2[0], c2[1] * 0.8, c2[2] > 50 ? c2[2] * 0.7 : min(100, c2[2] + 25) };
        fillC(g, tex2, 100);
        int ci = 0;
        for (float x = s * 0.035; x < s; x += s * 0.07, ci++) for (float y = s * 0.335 + (ci % 2) * s * 0.035; y < s * 0.69; y += s * 0.07) {
          if (ci % 2 == 0) diamond(g, x, y, s * 0.012, s * 0.018);
          else { g.rect(x - s * 0.012, y - s * 0.004, s * 0.024, s * 0.008); g.rect(x - s * 0.004, y - s * 0.012, s * 0.008, s * 0.024); }
        }
        fillC(g, c1, 100);
        g.rect(0, s * 0.27, s, lw * 2.5);
        g.rect(0, s * 0.7, s, lw * 2.5);
        g.noFill();
        strokeC(g, c1, 100);
        g.strokeWeight(lw * 1.6);
        g.arc(s * 0.3, s * 0.12, s * 0.3, s * 0.2, 0, PI);
        g.arc(s * 0.75, s * 0.88, s * 0.3, s * 0.2, PI, TWO_PI);
        g.noStroke();
        break;
      }
      case 4: {   // sunburst of dark rays from a corner
        float cx = s * (r.nextBoolean() ? 0.1 : 0.9), cy = s * (r.nextBoolean() ? 0.1 : 0.9);
        int n = 20;
        for (int i = 0; i < n; i++) {
          float a1 = TWO_PI * i / n, a2 = TWO_PI * (i + 0.5) / n;
          fillC(g, i % 2 == 0 ? c3 : c1, 100);
          g.triangle(cx, cy, cx + cos(a1) * s * 1.5, cy + sin(a1) * s * 1.5, cx + cos(a2) * s * 1.5, cy + sin(a2) * s * 1.5);
        }
        fillC(g, c2, 100);
        star8(g, cx, cy, s * 0.16, c2, c3, lw);
        break;
      }
      default: {  // small square tiles in two close tones
        float m = s / 8;
        float[] c1b = { c1[0], c1[1] * 0.75, min(100, c1[2] + 10) };
        for (int i = 0; i < 8; i++) for (int j = 0; j < 8; j++) {
          fillC(g, (i + j) % 2 == 0 ? c1 : c1b, 100);
          g.rect(i * m + lw * 0.6, j * m + lw * 0.6, m - 1.2 * lw, m - 1.2 * lw);
        }
      }
    }
  }

  // Phenomenon 3: Moorish rosette tile — an eight-point star ringed by hexagonal petals,
  // with quarter rosettes in the corners (so the pattern carries on across tiles)
  void paintRosette(PGraphics g, int k, float s) {
    float[] ground = vary(cLight, 4, 3, 2);
    float[] cStar  = (k % 2 == 0) ? cDark : cAcc;
    float[] cPetal = (k < 2) ? cAcc2 : cBase;
    float[] cKite  = (k % 2 == 0) ? cAcc : cDark;
    g.noStroke();
    fillC(g, ground, 100);
    g.rect(0, 0, s, s);
    // a 2 × 2 repeat with half rosettes on the edges, so every shard shows whole rosettes
    for (int i = 0; i <= 4; i++) for (int j = 0; j <= 4; j++) {
      if ((i + j) % 2 != 0) continue;
      rosette(g, i * s / 4, j * s / 4, s * 0.22, cStar, cPetal, cKite);
    }
  }

  void rosette(PGraphics g, float x, float y, float R, float[] cStar, float[] cPetal, float[] cKite) {
    g.pushMatrix();
    g.translate(x, y);
    for (int i = 0; i < 8; i++) {
      float a = TWO_PI * i / 8;
      fillC(g, vary(cPetal, 3, 5, 6), 100);
      hexagon(g, cos(a) * R * 0.6, sin(a) * R * 0.6, R * 0.21, a);
      fillC(g, cKite, 90);
      float b = a + TWO_PI / 16;
      g.quad(cos(b) * R * 0.78, sin(b) * R * 0.78,
             cos(b + 0.13) * R * 0.95, sin(b + 0.13) * R * 0.95,
             cos(b) * R * 1.1,  sin(b) * R * 1.1,
             cos(b - 0.13) * R * 0.95, sin(b - 0.13) * R * 0.95);
    }
    star8(g, 0, 0, R * 0.32, cStar, cStar, 0.1);
    fillC(g, cLight, 100);
    g.ellipse(0, 0, R * 0.14, R * 0.14);
    g.popMatrix();
  }

  void hexagon(PGraphics g, float x, float y, float rad, float rot) {
    g.beginShape();
    for (int i = 0; i < 6; i++) g.vertex(x + cos(rot + TWO_PI * i / 6) * rad, y + sin(rot + TWO_PI * i / 6) * rad);
    g.endShape(CLOSE);
  }

  // Phenomenon 1: Modernista ornamental tiles (like the benches of Park Güell): bands with
  // scalloped arches, blue dots and little sprigs; corner fans; interlaced strapwork.
  // Fine black outlines, as painted by hand. Six variants, three designs × two colourways.
  void paintModernista(PGraphics g, int k, float s) {
    float[] band = (k % 2 == 0) ? cAcc2 : cBase, other = (k % 2 == 0) ? cBase : cAcc2;
    float[] dot = (k % 2 == 0) ? cBase : cAcc, line = cDark;
    float lw = s * 0.012;
    g.noStroke();
    fillC(g, vary(cLight, 4, 3, 2), 100);
    g.rect(0, 0, s, s);
    switch (k % 3) {
      case 0: {   // two bands of scalloped arches facing each other, dots in the arches, sprigs between
        for (int side = 0; side < 2; side++) {
          float y0 = side == 0 ? 0 : s, dir = side == 0 ? 1 : -1;
          float[] c = side == 0 ? band : other;
          fillC(g, c, 100);
          g.rect(0, side == 0 ? 0 : s * 0.75, s, s * 0.25);
          for (int i = 0; i < 3; i++) g.arc(s * (i + 0.5) / 3, y0 + dir * s * 0.25, s / 3, s * 0.3, side == 0 ? 0 : PI, side == 0 ? PI : TWO_PI);
          g.noFill();
          strokeC(g, line, 90);
          g.strokeWeight(lw);
          for (int i = 0; i < 3; i++) {
            g.arc(s * (i + 0.5) / 3, y0 + dir * s * 0.25, s / 3, s * 0.3, side == 0 ? 0 : PI, side == 0 ? PI : TWO_PI);
            g.arc(s * (i + 0.5) / 3, y0 + dir * s * 0.25, s / 3 * 0.7, s * 0.3 * 0.7, side == 0 ? 0 : PI, side == 0 ? PI : TWO_PI);
          }
          g.line(0, y0 + dir * s * 0.05, s, y0 + dir * s * 0.05);
          g.line(0, y0 + dir * s * 0.08, s, y0 + dir * s * 0.08);
          g.noStroke();
          for (int i = 0; i < 3; i++) {
            float x = s * (i + 0.5) / 3, yd = y0 + dir * s * 0.29;
            fillC(g, line, 90);
            diamond(g, x, yd, s * 0.045, s * 0.07);
            fillC(g, dot, 100);
            diamond(g, x, yd, s * 0.03, s * 0.05);
          }
        }
        for (int i = 0; i < 3; i++) sprig(g, s * (i + 0.0) / 3 + s / 6 + (i % 2) * s * 0.02, s * 0.55, s * 0.08, line, cAcc);
        break;
      }
      case 1: {   // fans in the four corners and a diamond in the middle
        for (int c = 0; c < 4; c++) {
          float cx = (c % 2) * s, cy = (c / 2) * s, R = s * 0.42;
          float a0 = (c == 0) ? 0 : (c == 1) ? HALF_PI : (c == 2) ? -HALF_PI : PI;
          fillC(g, c % 3 == 0 ? band : other, 100);
          g.arc(cx, cy, 2 * R, 2 * R, a0, a0 + HALF_PI);
          g.noFill();
          strokeC(g, line, 90);
          g.strokeWeight(lw);
          g.arc(cx, cy, 2 * R, 2 * R, a0, a0 + HALF_PI);
          g.arc(cx, cy, 1.55 * R, 1.55 * R, a0, a0 + HALF_PI);
          for (int i = 1; i < 7; i++) {
            float a = a0 + HALF_PI * i / 7;
            g.line(cx + cos(a) * R * 0.78, cy + sin(a) * R * 0.78, cx + cos(a) * R, cy + sin(a) * R);
          }
          g.noStroke();
          float da = a0 + QUARTER_PI;
          fillC(g, line, 90);
          diamond(g, cx + cos(da) * R * 0.42, cy + sin(da) * R * 0.42, s * 0.05, s * 0.075);
          fillC(g, dot, 100);
          diamond(g, cx + cos(da) * R * 0.42, cy + sin(da) * R * 0.42, s * 0.034, s * 0.055);
        }
        fillC(g, band, 100);
        strokeC(g, line, 90);
        g.strokeWeight(lw);
        g.quad(s * 0.5, s * 0.34, s * 0.62, s * 0.5, s * 0.5, s * 0.66, s * 0.38, s * 0.5);
        g.noStroke();
        sprig(g, s * 0.5, s * 0.26, s * 0.07, line, cAcc);
        break;
      }
      default: {  // interlaced strapwork: a diamond crossing a square, with a dot in the middle
        g.noFill();
        g.strokeJoin(MITER);
        for (int pass = 0; pass < 2; pass++) {
          strokeC(g, pass == 0 ? line : dot, 100);
          g.strokeWeight(pass == 0 ? s * 0.1 : s * 0.065);
          g.quad(s * 0.5, -s * 0.02, s * 1.02, s * 0.5, s * 0.5, s * 1.02, -s * 0.02, s * 0.5);
          g.rect(s * 0.22, s * 0.22, s * 0.56, s * 0.56);
        }
        strokeC(g, cLight, 100);   // the white line along each strap
        g.strokeWeight(s * 0.012);
        g.quad(s * 0.5, -s * 0.02, s * 1.02, s * 0.5, s * 0.5, s * 1.02, -s * 0.02, s * 0.5);
        g.rect(s * 0.22, s * 0.22, s * 0.56, s * 0.56);
        g.noStroke();
        fillC(g, band, 100);
        diamond(g, s * 0.5, s * 0.5, s * 0.1, s * 0.1);
        for (int i = 0; i < 4; i++) {   // small triangles in the corners
          float cx = (i % 2) * s, cy = (i / 2) * s;
          fillC(g, band, 100);
          g.triangle(cx, cy, cx + (i % 2 == 0 ? 1 : -1) * s * 0.16, cy, cx, cy + (i / 2 == 0 ? 1 : -1) * s * 0.16);
        }
      }
    }
  }

  // A small lozenge (half-width w, half-height h)
  void diamond(PGraphics g, float x, float y, float w, float h) {
    g.quad(x, y - h, x + w, y, x, y + h, x - w, y);
  }

  // A little painted sprig: three dark leaves and two coloured buds
  void sprig(PGraphics g, float x, float y, float k, float[] leaf, float[] bud) {
    fillC(g, leaf, 90);
    for (int i = -1; i <= 1; i++) {
      g.pushMatrix();
      g.translate(x, y);
      g.rotate(i * 0.7);
      g.triangle(-k * 0.18, 0, k * 0.18, 0, 0, -k);
      g.popMatrix();
    }
    fillC(g, bud, 100);
    g.ellipse(x - k * 0.55, y - k * 0.25, k * 0.28, k * 0.28);
    g.ellipse(x + k * 0.55, y - k * 0.25, k * 0.28, k * 0.28);
  }

  // An eight-point star: two overlapping squares, outlined like hand-painted tiles
  void star8(PGraphics g, float x, float y, float rad, float[] c, float[] line, float lw) {
    g.pushMatrix();
    g.translate(x, y);
    fillC(g, c, 100);
    strokeC(g, line, 85);
    g.strokeWeight(lw);
    for (int k = 0; k < 2; k++) {
      g.rotate(QUARTER_PI);
      g.rect(-rad * 0.7, -rad * 0.7, rad * 1.4, rad * 1.4);
    }
    g.noStroke();
    g.popMatrix();
  }

  // Phenomenon 5: repeated Valencian tiles — eight-point stars and small crosses
  void paintStars(PGraphics g) {
    g.background(cLight[0], cLight[1], cLight[2]);
    mottle(g, cLight, 8, 10);
    float m = u * rnd(r, 1.3, 1.8), lw = u * 0.035;
    float ox = rnd(r, 0, m), oy = rib + rnd(r, 0, m);
    for (float x = ox - m; x < W + m; x += m) {
      for (float y = oy - m; y < H + m; y += m) {
        star8(g, x, y, m * 0.36, cBase, cDark, lw);
        fillC(g, new float[] { lerpAngle(cBase[0], cAcc[0], 0.4), cBase[1] * 0.7, min(100, cBase[2] + 18) }, 100);
        diamond(g, x, y, m * 0.05, m * 0.05);
        // small cross between the stars
        fillC(g, cAcc2, 100);
        float cx = x + m / 2, cy = y + m / 2, a = m * 0.09, b = m * 0.03;
        g.rect(cx - a, cy - b, 2 * a, 2 * b);
        g.rect(cx - b, cy - a, 2 * b, 2 * a);
      }
    }
  }

  // Phenomenon 6: parallel bands — interlaced chains between plain stripes
  void paintBands(PGraphics g) {
    g.background(cLight[0], cLight[1], cLight[2]);
    mottle(g, cLight, 8, 10);
    g.pushMatrix();
    g.translate(W / 2, rib + CH / 2);
    g.rotate(rnd(r, -0.35, 0.35));
    float span = dist(0, 0, W, CH), gap = u * rnd(r, 1.6, 2.2), lw = u * 0.035;
    int k = 0;
    for (float y0 = -span; y0 < span; y0 += gap, k++) {
      if (k % 2 == 0) {
        // stripe pair
        fillC(g, cBase, 100);
        g.rect(-span, y0, 2 * span, gap * 0.28);
        fillC(g, cAcc2, 100);
        g.rect(-span, y0 + gap * 0.36, 2 * span, gap * 0.1);
      } else {
        // chain of links
        float h = gap * 0.32, step = h * 1.4;
        g.noFill();
        for (int pass = 0; pass < 2; pass++) {
          strokeC(g, pass == 0 ? cDark : cAcc, 100);
          g.strokeWeight(pass == 0 ? h * 0.42 : h * 0.26);
          for (float x = -span; x < span; x += step) {
            g.beginShape();
            g.vertex(x, y0 + gap * 0.5 - h);
            g.vertex(x + step / 2, y0 + gap * 0.5);
            g.vertex(x, y0 + gap * 0.5 + h);
            g.vertex(x - step / 2, y0 + gap * 0.5);
            g.endShape(CLOSE);
          }
        }
        g.noStroke();
      }
    }
    g.popMatrix();
  }

  void paintChecker(PGraphics g) {
    g.background(cDark[0], cDark[1], cDark[2]);
    g.pushMatrix();
    g.translate(W / 2, rib + CH / 2);
    g.rotate(rnd(r, -0.5, 0.5));
    float m = u * rnd(r, 1.0, 1.4), span = dist(0, 0, W, CH);
    g.noStroke();
    int i = 0;
    for (float x = -span; x < span; x += m, i++) {
      int j = 0;
      for (float y = -span; y < span; y += m, j++) {
        float[] c = ((i + j) % 2 == 0) ? cAcc2 : cBase;
        fillC(g, vary(c, 3, 5, 6), 100);
        if ((i + j) % 3 == 0) g.triangle(x, y, x + m, y, x, y + m);
        else                  g.triangle(x + m, y, x + m, y + m, x, y + m);
      }
    }
    g.popMatrix();
    mottle(g, cDark, 6, 8);
  }

  // ── Ribbon: dark straight pieces along the top edge (the borders of the bands) ──
  // Returns the rest of the cell (where the shards go).

  ArrayList<PVector> ribbon() {
    PVector[] top = patch.top, bot = patch.bot;
    int n = top.length;
    // Lower edge of the ribbon: the top polyline shifted down, ending on the cell's sides
    PVector[] low = new PVector[n];
    for (int i = 0; i < n; i++) low[i] = new PVector(top[i].x, top[i].y + rib);
    low[0]     = PVector.lerp(top[0],     bot[0],               rib / max(1, bot[0].y - top[0].y));
    low[n - 1] = PVector.lerp(top[n - 1], bot[bot.length - 1], rib / max(1, bot[bot.length - 1].y - top[n - 1].y));

    // Cuts: at every corner of the polyline, plus some in between
    FloatList cuts = new FloatList();
    for (int i = 0; i < n - 1; i++) {
      float xa = top[i].x, xb = top[i + 1].x;
      cuts.append(xa);
      int k = max(1, round((xb - xa) / (rib * rnd(r, 1.2, 2.0))));
      for (int j = 1; j < k; j++) cuts.append(lerp(xa, xb, (j + rnd(r, -0.25, 0.25)) / k));
    }
    cuts.append(top[n - 1].x);

    // Where each cut meets the lower edge (slanted a little, shared by both neighbours)
    int nc = cuts.size();
    float[] lowX = new float[nc];
    for (int i = 0; i < nc; i++) lowX[i] = cuts.get(i) + rnd(r, -0.25, 0.25) * rib;
    lowX[0]      = low[0].x;
    lowX[nc - 1] = low[n - 1].x;

    for (int i = 0; i < nc - 1; i++) {
      ArrayList<PVector> p = sliceAt(top, cuts.get(i), cuts.get(i + 1));
      ArrayList<PVector> q = sliceAt(low, lowX[i], lowX[i + 1]);
      for (int j = q.size() - 1; j >= 0; j--) p.add(q.get(j));
      addPiece(p, vary(cRib, 4, 6, 7), false);
    }

    ArrayList<PVector> rest = new ArrayList<PVector>();
    for (PVector q : low) rest.add(q.copy());
    for (int i = bot.length - 1; i >= 0; i--) rest.add(bot[i].copy());
    return rest;
  }

  // ── Breaking the tile like real ceramic ──────────────────
  // The biggest piece is cut by a straight crack (across its long side, at an
  // irregular angle) again and again until the pieces reach their size; then
  // some pieces lose a corner, which stays as a small triangular chip.
  // Pieces end up with 3 to 7 sides and odd angles, like broken tile.

  void shatter(ArrayList<PVector> content) {
    float minA = sq(u) * 0.05;

    // A few spots where the tile was hit harder: crushed into small chips
    ArrayList<PVector> crush = new ArrayList<PVector>();
    for (int i = 0, n = 1 + r.nextInt(3); i < n; i++) crush.add(new PVector(X0 + rnd(r, 0, W), Y0 + rib + rnd(r, 0, CH)));

    ArrayList<ArrayList<PVector>> todo = new ArrayList<ArrayList<PVector>>();
    ArrayList<ArrayList<PVector>> done = new ArrayList<ArrayList<PVector>>();
    todo.add(content);
    while (todo.size() > 0) {
      ArrayList<PVector> p = todo.remove(todo.size() - 1);
      float area = abs(signedArea(p));
      // Each piece wants its own size: from big plate pieces to small chips
      float target = sq(u) * pow(2, rnd(r, -1.8, 1.6));
      PVector c = polyCenter(p);
      for (PVector k : crush) target *= lerp(0.2, 1, constrain(PVector.dist(c, k) / (u * 2), 0, 1));
      if (area <= target || done.size() > 500) { done.add(p); continue; }
      ArrayList<PVector>[] halves = crack(p, minA);
      if (halves == null) { done.add(p); continue; }
      todo.add(halves[0]);
      todo.add(halves[1]);
    }

    // Chipped corners (up to two): fewer for phenomena with many 4-sided shards (CUT_STYLE)
    ArrayList<ArrayList<PVector>> pieces = new ArrayList<ArrayList<PVector>>();
    for (ArrayList<PVector> p : done) {
      for (int k = 0; k < 2; k++) {
        if (p.size() < 4 || r.nextFloat() > (1 - quadProb) * 0.7) break;
        int n = p.size(), i = r.nextInt(n);
        PVector v = p.get(i), a = p.get((i - 1 + n) % n), b = p.get((i + 1) % n);
        PVector ca = PVector.lerp(v, a, rnd(r, 0.2, 0.55)), cb = PVector.lerp(v, b, rnd(r, 0.2, 0.55));
        PVector normal = new PVector(-(cb.y - ca.y), cb.x - ca.x);
        if (PVector.sub(v, ca).dot(normal) > 0) normal.mult(-1);   // the corner on the kept side of clipPlane
        ArrayList<PVector> rest = clipPlane(p, ca, PVector.mult(normal, -1));
        ArrayList<PVector> chip = clipPlane(p, ca, normal);
        if (rest == null || chip == null || abs(signedArea(chip)) < minA * 0.6 || chunkiness(chip) < 0.03) break;
        pieces.add(chip);
        p = rest;
      }
      pieces.add(p);
    }

    // Phenomena 3 and 4: neighbouring shards come in groups from the same broken source tile
    boolean clustered = (phen == 1 || phen == 3 || phen == 4);
    ArrayList<PVector> srcSeed = new ArrayList<PVector>();
    IntList srcCell = new IntList();
    FloatList srcRot = new FloatList();
    if (clustered) {
      int ns = max(2, round(W * CH / sq(cellUnits * 0.8)));
      for (int i = 0; i < ns; i++) {
        srcSeed.add(new PVector(X0 + rnd(r, 0, W), Y0 + rib + rnd(r, 0, CH)));
        // rosettes: mostly rosette tiles, some plain ones in between
        srcCell.append(phen == 3 ? (r.nextFloat() < 0.88 ? r.nextInt(4) : 4 + r.nextInt(2)) : r.nextInt(AC * AR));
        srcRot.append(HALF_PI * r.nextInt(4) + rnd(r, -0.15, 0.15));
      }
    }

    // Neighbouring shards never share a tone (phenomena 1, 2: tone = which plain tile)
    int[] tone = new int[pieces.size()];
    PVector[] cen = new PVector[pieces.size()];
    for (int i = 0; i < pieces.size(); i++) {
      cen[i] = polyCenter(pieces.get(i));
      IntList avoid = new IntList();
      for (int j = 0; j < i; j++) if (PVector.dist(cen[i], cen[j]) < u * 1.3) avoid.append(tone[j]);
      tone[i] = pickTone(avoid.array());
      if (clustered) {
        int best = 0;
        for (int j = 1; j < srcSeed.size(); j++) if (PVector.dist(cen[i], srcSeed.get(j)) < PVector.dist(cen[i], srcSeed.get(best))) best = j;
        mapCell = srcCell.get(best);
        mapX = srcSeed.get(best).x;
        mapY = srcSeed.get(best).y;
        mapRot = srcRot.get(best);
      } else if (atlas) {
        mapCell = tone[i];
        mapX = cen[i].x + rnd(r, -0.25, 0.25) * cellUnits;
        mapY = cen[i].y + rnd(r, -0.25, 0.25) * cellUnits;
        mapRot = rnd(r, 0, TWO_PI);
      }
      addPiece(pieces.get(i), new float[] { 0, 0, rnd(r, 88, 100) }, true);   // each shard glazed a touch differently
    }
  }

  // One straight crack across the piece. null if it would only shave off a sliver.
  ArrayList<PVector>[] crack(ArrayList<PVector> p, float minA) {
    PVector c = polyCenter(p);
    // Long axis of the piece
    float sxx = 0, syy = 0, sxy = 0;
    for (PVector q : p) {
      float dx = q.x - c.x, dy = q.y - c.y;
      sxx += dx * dx; syy += dy * dy; sxy += dx * dy;
    }
    float axis = 0.5 * atan2(2 * sxy, sxx - syy);
    float ext = 0;
    for (PVector q : p) ext = max(ext, abs((q.x - c.x) * cos(axis) + (q.y - c.y) * sin(axis)));

    for (int tries = 0; tries < 6; tries++) {
      PVector at, normal;
      float kind = r.nextFloat();
      if (kind < 0.25) {
        // From a corner towards the opposite side → long triangles and odd shapes
        PVector v = p.get(r.nextInt(p.size()));
        PVector far = PVector.add(c, PVector.mult(PVector.sub(c, v), rnd(r, 0.3, 1.0)));
        far.add(rnd(r, -0.3, 0.3) * ext, rnd(r, -0.3, 0.3) * ext);
        at = v;
        normal = new PVector(-(far.y - v.y), far.x - v.x);
      } else {
        // Across the long axis (tilted, off-centre), or now and then in any direction
        float ang = (kind < 0.45) ? rnd(r, 0, TWO_PI) : axis + rnd(r, -1, 1) * (0.3 + jit * 1.6);
        normal = new PVector(cos(ang), sin(ang));
        at = PVector.add(c, PVector.mult(new PVector(cos(axis), sin(axis)), rnd(r, -0.45, 0.45) * ext));
      }
      if (normal.mag() < 1e-4) continue;
      ArrayList<PVector> a = clipPlane(p, at, normal);
      ArrayList<PVector> b = clipPlane(p, at, PVector.mult(normal, -1));
      if (a != null && b != null && abs(signedArea(a)) > minA && abs(signedArea(b)) > minA
          && chunkiness(a) > 0.03 && chunkiness(b) > 0.03) {   // no long glass-like splinters
        ArrayList<PVector>[] out = new ArrayList[2];
        out[0] = a;
        out[1] = b;
        return out;
      }
    }
    return null;
  }

  // Leaves the grout around a shard, keeps where it was on the painted tile —
  // slightly off, as when it is set by hand — and moves it to tile-local coordinates
  void addPiece(ArrayList<PVector> poly, float[] col, boolean painted) {
    ArrayList<PVector> c = insetPoly(poly, GROUT_WIDTH * rnd(r, 0.7, 1.5));
    if (c == null || abs(signedArea(c)) < sq(GROUT_WIDTH * 2.5)) return;
    int n = c.size();
    PVector c0 = polyCenter(c);

    Piece pc = new Piece();
    pc.x = new float[n];
    pc.y = new float[n];
    if (painted && atlas) {
      // A piece of one of the source tiles in the atlas
      pc.u = new float[n];
      pc.v = new float[n];
      float ca = cos(mapRot), sa = sin(mapRot), cu = cellUnits;
      // If the shard sticks out of its source tile, take its picture around its own centre
      // instead (same tile, same turn): never stretch the edge of the picture
      float mx = mapX, my = mapY;
      for (int i = 0; i < n; i++) {
        float dx = c.get(i).x - mx, dy = c.get(i).y - my;
        if (abs((dx * ca - dy * sa) / cu) > 0.48 || abs((dx * sa + dy * ca) / cu) > 0.48) { mx = c0.x; my = c0.y; break; }
      }
      for (int i = 0; i < n; i++) {
        float dx = c.get(i).x - mx, dy = c.get(i).y - my;
        float lu = constrain((dx * ca - dy * sa) / cu + 0.5, 0.01, 0.99);
        float lv = constrain((dx * sa + dy * ca) / cu + 0.5, 0.01, 0.99);
        pc.u[i] = ((mapCell % AC) + lu) / AC;
        pc.v[i] = ((mapCell / AC) + lv) / AR;
      }
    } else if (painted) {
      pc.u = new float[n];
      pc.v = new float[n];
      float ang = rnd(r, -0.05, 0.05), du = rnd(r, -0.006, 0.006), dv = rnd(r, -0.006, 0.006);
      float ca = cos(ang), sa = sin(ang);
      for (int i = 0; i < n; i++) {
        float ox = c.get(i).x - c0.x, oy = c.get(i).y - c0.y;
        pc.u[i] = (c0.x + ox * ca - oy * sa - X0) / W + du;
        pc.v[i] = (c0.y + ox * sa + oy * ca - Y0) / H + dv;
      }
    }
    for (int i = 0; i < n; i++) {
      pc.x[i] = c.get(i).x - origin.x;
      pc.y[i] = c.get(i).y - origin.y;
    }
    pc.cx = c0.x - origin.x;
    pc.cy = c0.y - origin.y;
    pc.area = abs(signedArea(c));

    // Relief: every shard sits a little tilted in the mortar and has a rounded rim
    float ta = rnd(r, 0, TWO_PI), tm = rnd(r, 0.3, 1);
    float tx = cos(ta) * tm, ty = sin(ta) * tm;
    pc.lit  = tx * LIGHT_X + ty * LIGHT_Y;
    pc.spec = pow(max(0, pc.lit), 3) * rnd(r, 0.4, 1) + (r.nextFloat() < 0.08 ? 0.5 : 0);   // a few catch a glint
    float pr = 1;
    for (int i = 0; i < n; i++) pr = max(pr, dist(pc.x[i], pc.y[i], pc.cx, pc.cy));
    pc.grad = new float[n];
    for (int i = 0; i < n; i++) pc.grad[i] = ((pc.x[i] - pc.cx) * tx + (pc.y[i] - pc.cy) * ty) / pr;

    ArrayList<PVector> inner = insetPoly(c, min(RIM_PX / RENDER_SCALE, sqrt(pc.area) * 0.12));
    pc.chipped = new boolean[n];
    for (int i = 0; i < n; i++) pc.chipped[i] = r.nextFloat() < 0.15;
    if (inner != null && inner.size() == n) {
      pc.rx = new float[n];
      pc.ry = new float[n];
      pc.rimLit = new float[n];
      float sg = signedArea(c) > 0 ? 1 : -1;
      for (int i = 0; i < n; i++) {
        pc.rx[i] = inner.get(i).x - origin.x;
        pc.ry[i] = inner.get(i).y - origin.y;
        PVector a = c.get(i), b = c.get((i + 1) % n);
        PVector out = new PVector((b.y - a.y) * sg, -(b.x - a.x) * sg).normalize();   // outward normal of the edge
        pc.rimLit[i] = out.x * LIGHT_X + out.y * LIGHT_Y;
      }
    }
    pc.h = col[0];
    pc.s = col[1];
    pc.b = col[2];

    entrance(pc);
    pc.delay = pc.area;   // replaced by a rank in orderAssembly()
    pieces.add(pc);
  }

  // How the shard comes in while the tile assembles on the main wall: word_class,
  // echoing the particle shapes of the original sketch. Order stays small → big.
  void entrance(Piece pc) {
    float R = max(W, H) * 0.5;
    float d = dist(0, 0, pc.cx, pc.cy) + 1;
    float ux = pc.cx / d, uy = pc.cy / d;      // direction from the centre of the tile
    pc.fx = 0; pc.fy = 0; pc.frot = 0; pc.fs = 1;
    pc.fz = (pieces.size() * 0.6180339f) % 1;   // how far back it starts (no extra random draws: tiles stay the same)
    switch (wc) {
      case 1: {   // Noun — circle: gathers from a ring all around the tile
        float rr = R * rnd(r, 1.2, 1.5);
        pc.fx = ux * rr - pc.cx;
        pc.fy = uy * rr - pc.cy;
        pc.frot = rnd(r, -0.3, 0.3);
        pc.fs = 1.1;
        break;
      }
      case 2:     // Verb — streak: sweeps in from the left, fast and long
        pc.fx = -R * rnd(r, 1.2, 2.0);
        pc.fy = rnd(r, -0.08, 0.08) * R;
        pc.frot = rnd(r, -0.15, 0.15);
        break;
      case 3:     // Adjective — aura: appears in its place, growing out of nothing
        pc.fs = 0.05;
        pc.frot = rnd(r, -0.5, 0.5);
        break;
      case 4: {   // Adverb — arc: swirls in around the centre
        float a = rnd(r, 1.0, 1.8);
        pc.fx = (pc.cx * cos(a) - pc.cy * sin(a)) * 1.3 - pc.cx;
        pc.fy = (pc.cx * sin(a) + pc.cy * cos(a)) * 1.3 - pc.cy;
        pc.frot = a;
        break;
      }
      case 5:     // Preposition — connector: from above and below, meeting in the middle
        pc.fy = (pc.cy < 0 ? -1 : 1) * R * rnd(r, 0.9, 1.4);
        pc.fx = rnd(r, -0.05, 0.05) * R;
        break;
      case 6:     // Determiner — point: bursts out of the centre
        pc.fx = -pc.cx;
        pc.fy = -pc.cy;
        pc.fs = 0.3;
        pc.frot = rnd(r, -1.2, 1.2);
        break;
      case 7:     // Pronoun — ring: straight out of the depth, turning
        pc.fx = ux * u * rnd(r, 0.2, 0.6);
        pc.fy = uy * u * rnd(r, 0.2, 0.6);
        r.nextFloat();   // (was its depth) keeps the random sequence, so saved tiles look the same
        pc.frot = rnd(r, -0.8, 0.8);
        pc.fs = 1.2;
        break;
      default:    // Conjunction — fork: from the left and the right, joining
        pc.fx = (pc.cx < 0 ? -1 : 1) * R * rnd(r, 0.9, 1.5);
        pc.fy = rnd(r, -0.1, 0.1) * R;
        pc.frot = rnd(r, -0.2, 0.2);
    }
  }

  void makeBed(ArrayList<PVector> outline) {
    int n = outline.size();
    gx = new float[n];
    gy = new float[n];
    float x0 = Float.MAX_VALUE, x1 = -Float.MAX_VALUE, y0 = Float.MAX_VALUE, y1 = -Float.MAX_VALUE;
    for (int i = 0; i < n; i++) {
      gx[i] = outline.get(i).x - origin.x;
      gy[i] = outline.get(i).y - origin.y;
      x0 = min(x0, gx[i]); x1 = max(x1, gx[i]);
      y0 = min(y0, gy[i]); y1 = max(y1, gy[i]);
      radius = max(radius, dist(0, 0, gx[i], gy[i]));
    }
    tileW = x1 - x0;
    tileH = y1 - y0;
  }

  // Assembly order: small shards first, the big ones at the back last
  void orderAssembly() {
    int n = pieces.size();
    if (n == 0) return;
    ArrayList<Piece> sorted = new ArrayList<Piece>(pieces);
    java.util.Collections.sort(sorted, (a, b) -> Float.compare(a.delay, b.delay));
    for (int i = 0; i < n; i++) {
      sorted.get(i).delay = 0.85 * i / max(1, n - 1) + rnd(r, 0, 0.15);
    }
  }

  // ── Drawing (centred on the tile's origin, 1 unit = 1 matrix unit) ──

  // Finished tile. The grout bed is only laid when it is set on WALL 1 (withGrout);
  // before that the shards travel loose, with the dark room showing between them.
  void drawFlat(PGraphics pg, float alpha) { drawFlat(pg, alpha, false); }

  void drawFlat(PGraphics pg, float alpha, boolean withGrout) {
    pg.noStroke();
    pg.textureMode(NORMAL);
    if (withGrout) {
      drawBed(pg, alpha);
      for (Piece p : pieces) drawGroutShadow(pg, p, alpha);
    }
    for (Piece p : pieces) drawPiece(pg, p, alpha, 0, 0);
  }

  // The grout is sunk below the shards: darker right next to each one
  void drawGroutShadow(PGraphics pg, Piece p, float alpha) {
    if (RELIEF <= 0) return;
    int n = p.x.length;
    float d = AO_PX / RENDER_SCALE;
    pg.beginShape(QUADS);
    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      float ex = p.x[j] - p.x[i], ey = p.y[j] - p.y[i], l = max(0.001, sqrt(ex * ex + ey * ey));
      float nx = ey / l, ny = -ex / l;
      if ((p.x[i] - p.cx) * nx + (p.y[i] - p.cy) * ny < 0) { nx = -nx; ny = -ny; }   // outwards
      pg.fill(0, 0, 0, alpha * 0.3 * RELIEF);
      pg.vertex(p.x[i], p.y[i]);
      pg.vertex(p.x[j], p.y[j]);
      pg.fill(0, 0, 0, 0);
      pg.vertex(p.x[j] + nx * d, p.y[j] + ny * d);
      pg.vertex(p.x[i] + nx * d, p.y[i] + ny * d);
    }
    pg.endShape();
  }

  // a = assembly progress 0..1: small shards settle first, drifting in from just
  // in front of the wall (lift); the big ones at the back follow.
  // a = assembly progress 0..1. Small shards first: each one comes from far behind
  // the wall (depth), dark and soft, and turns sharp and lit as it reaches its place.
  void drawAssembling(PGraphics pg, float alpha, float a, float depth) {
    if (a >= 1) { drawFlat(pg, alpha); return; }
    pg.noStroke();
    pg.textureMode(NORMAL);
    for (int id = 0; id < pieces.size(); id++) {
      Piece p = pieces.get(id);
      float q = constrain((a - p.delay * 0.45) / 0.55, 0, 1);   // long way in: the depth can be felt
      if (q <= 0) continue;
      float k = pow(1 - q, 2.2);   // 1 = far away, 0 = in place (ease out)
      pg.pushMatrix();
      // Far away the shards are scattered wide; they gather as they come close
      float sa = id * 2.39996, sr = (0.35 + 0.65 * ((id * 0.7548777f) % 1)) * ASSEMBLE_SPREAD * max(W, H) * k;
      pg.translate(p.cx + p.fx * k + cos(sa) * sr, p.cy + p.fy * k + sin(sa) * sr, -(0.5 + 0.5 * p.fz) * depth * k);
      pg.rotate(p.frot * k);
      pg.scale(lerp(1, p.fs, k));
      float a0 = alpha * smooth01(q * 1.5);
      float dim = 1 - 0.9 * k;                // deep in the dark far away
      // Out of focus while far: soft, wider ghosts of the piece that fade as it arrives
      for (int g = 2; g >= 1 && k > 0.02; g--) {
        pg.pushMatrix();
        pg.scale(1 + 0.35 * g * k);
        drawPiece(pg, p, a0 * 0.25 * k, p.cx, p.cy, dim);
        pg.popMatrix();
      }
      drawPiece(pg, p, a0 * (1 - 0.65 * k), p.cx, p.cy, dim);
      pg.popMatrix();
    }
  }


  // Only some of the pieces (a travelling fragment), centred on (ox, oy)
  void drawPieces(PGraphics pg, float alpha, IntList idx, float ox, float oy) {
    pg.noStroke();
    pg.textureMode(NORMAL);
    for (int i : idx) drawPiece(pg, pieces.get(i), alpha, ox, oy);
  }

  // Grout setting on WALL 1, t = 0..1: it seeps in under the shards, dark and wet,
  // and dries to its final light colour. Ends exactly like drawFlat(..., true).
  void drawSetting(PGraphics pg, float alpha, float t) {
    pg.noStroke();
    pg.textureMode(NORMAL);
    float dry = smooth01(t);
    float bed = alpha * smooth01(t / 0.45);
    drawBed(pg, bed, dry);
    for (Piece p : pieces) drawGroutShadow(pg, p, bed);
    for (Piece p : pieces) drawPiece(pg, p, alpha, 0, 0);
  }

  void drawBed(PGraphics pg, float alpha) { drawBed(pg, alpha, 1); }

  void drawBed(PGraphics pg, float alpha, float dry) {
    if (alpha <= 0) return;
    // Sandy mortar: a grain texture tinted with the grout colour (darker while wet)
    pg.textureWrap(REPEAT);
    pg.beginShape();
    pg.texture(groutTexture());
    pg.tint(GROUT_H, lerp(min(100, GROUT_S + 12), GROUT_S, dry), lerp(GROUT_B * 0.45, GROUT_B, dry), alpha);
    float k = RENDER_SCALE / 128.0;   // one grain per output pixel
    for (int i = 0; i < gx.length; i++) pg.vertex(gx[i], gy[i], gx[i] * k, gy[i] * k);
    pg.endShape(CLOSE);
    pg.noTint();
    pg.textureWrap(CLAMP);
  }

  void drawPiece(PGraphics pg, Piece p, float alpha, float ox, float oy) { drawPiece(pg, p, alpha, ox, oy, 1); }

  // dim < 1 darkens the piece (far away while assembling)
  void drawPiece(PGraphics pg, Piece p, float alpha, float ox, float oy, float dim) {
    int n = p.x.length;
    float light = 1 + RELIEF * 0.13 * p.lit;   // tilted towards the light or away from it

    // The glazed face
    pg.beginShape();
    if (p.u != null) {
      pg.texture(tex);
      pg.tint(0, 0, constrain(p.b * dim * light, 0, 100), alpha);
      for (int i = 0; i < n; i++) pg.vertex(p.x[i] - ox, p.y[i] - oy, p.u[i], p.v[i]);
    } else {
      pg.fill(p.h, p.s, constrain(p.b * dim * light, 0, 100), alpha);
      for (int i = 0; i < n; i++) pg.vertex(p.x[i] - ox, p.y[i] - oy);
    }
    pg.endShape(CLOSE);
    pg.noTint();
    if (RELIEF <= 0 && GLAZE <= 0) return;

    if (RELIEF > 0) {
      // Tilt: one side of the face a touch lighter, the other a touch darker
      pg.beginShape();
      for (int i = 0; i < n; i++) {
        float g = p.grad[i];
        if (g > 0) pg.fill(0, 0, 100, alpha * dim * RELIEF * 0.14 * g);
        else       pg.fill(0, 0, 0,   alpha * RELIEF * 0.16 * -g);
        pg.vertex(p.x[i] - ox, p.y[i] - oy);
      }
      pg.endShape(CLOSE);

      // Rounded rim: lit on the edges facing the light, shaded on the others;
      // here and there the glaze is chipped and the pale biscuit shows
      if (p.rx != null) {
        pg.beginShape(QUADS);
        for (int i = 0; i < n; i++) {
          int j = (i + 1) % n;
          float l = p.rimLit[i], aOut, aIn;
          if (p.chipped[i]) { pg.fill(40, 12, 90 * dim, alpha * 0.75); aIn = alpha * 0.75; }
          else if (l > 0)   { pg.fill(0, 0, 100, aOut = alpha * dim * RELIEF * 0.55 * l); aIn = 0; }
          else              { pg.fill(0, 0, 0,   aOut = alpha * RELIEF * 0.45 * -l);       aIn = 0; }
          pg.vertex(p.x[i] - ox, p.y[i] - oy);
          pg.vertex(p.x[j] - ox, p.y[j] - oy);
          if (!p.chipped[i]) pg.fill(0, 0, l > 0 ? 100 : 0, aIn);
          pg.vertex(p.rx[j] - ox, p.ry[j] - oy);
          pg.vertex(p.rx[i] - ox, p.ry[i] - oy);
        }
        pg.endShape();
      }
    }

    // Glaze highlight: only the shards tilted towards the light catch it
    if (GLAZE > 0 && p.spec > 0.05) {
      float pr = 0;
      for (int i = 0; i < n; i++) pr = max(pr, dist(p.x[i], p.y[i], p.cx, p.cy));
      float hx = p.cx + LIGHT_X * pr * 0.3, hy = p.cy + LIGHT_Y * pr * 0.3;
      pg.beginShape(TRIANGLE_FAN);
      pg.fill(0, 0, 100, alpha * dim * GLAZE / 100 * min(1, p.spec));
      pg.vertex(hx - ox, hy - oy);
      pg.fill(0, 0, 100, 0);
      for (int i = 0; i <= n; i++) {
        int k = i % n;
        pg.vertex(lerp(hx, p.x[k], 0.6) - ox, lerp(hy, p.y[k], 0.6) - oy);
      }
      pg.endShape();
    }
  }

}

// Grain of the mortar: near-white noise, tinted with the grout colour when drawn
PImage groutTex;

PImage groutTexture() {
  if (groutTex != null) return groutTex;
  Random g = new Random(7);
  groutTex = createImage(128, 128, RGB);
  groutTex.loadPixels();
  for (int i = 0; i < groutTex.pixels.length; i++) {
    float v = 232 + (float) g.nextGaussian() * 10;
    if (g.nextFloat() < 0.03) v -= 60;   // dark grains of sand
    if (g.nextFloat() < 0.02) v += 25;
    int c = constrain(round(v), 0, 255);
    groutTex.pixels[i] = 0xFF000000 | (c << 16) | (c << 8) | c;
  }
  groutTex.updatePixels();
  return groutTex;
}

// ********************
//   Polygon helpers
// ********************

// Area / perimeter²: 0.077 for a square, ~0.048 for an equilateral triangle, → 0 for splinters
float chunkiness(ArrayList<PVector> p) {
  float per = 0;
  for (int i = 0; i < p.size(); i++) per += PVector.dist(p.get(i), p.get((i + 1) % p.size()));
  return abs(signedArea(p)) / max(1e-4, per * per);
}

PVector polyCenter(ArrayList<PVector> p) {
  PVector c = new PVector();
  for (PVector q : p) c.add(q);
  return c.div(p.size());
}

// Points of a left → right polyline between x = xa and x = xb (ends included)
ArrayList<PVector> sliceAt(PVector[] line, float xa, float xb) {
  ArrayList<PVector> out = new ArrayList<PVector>();
  out.add(pointAt(line, xa));
  for (PVector q : line) if (q.x > xa + 0.01 && q.x < xb - 0.01) out.add(q.copy());
  out.add(pointAt(line, xb));
  return out;
}

PVector pointAt(PVector[] line, float x) {
  if (x <= line[0].x) return line[0].copy();
  for (int i = 0; i < line.length - 1; i++) {
    if (x <= line[i + 1].x) {
      float t = (x - line[i].x) / max(0.001, line[i + 1].x - line[i].x);
      return PVector.lerp(line[i], line[i + 1], t);
    }
  }
  return line[line.length - 1].copy();
}

// Keeps the part of the polygon on the side opposite to 'normal' from point m
ArrayList<PVector> clipPlane(ArrayList<PVector> in, PVector m, PVector normal) {
  ArrayList<PVector> out = new ArrayList<PVector>();
  int n = in.size();
  for (int i = 0; i < n; i++) {
    PVector a = in.get(i), b = in.get((i + 1) % n);
    float da = PVector.sub(a, m).dot(normal), db = PVector.sub(b, m).dot(normal);
    if (da <= 0) out.add(a);
    if ((da <= 0) != (db <= 0)) out.add(PVector.lerp(a, b, da / (da - db)));
  }
  return out.size() >= 3 ? out : null;
}

float signedArea(ArrayList<PVector> p) {
  float a = 0;
  int n = p.size();
  for (int i = 0; i < n; i++) {
    PVector q = p.get(i), w = p.get((i + 1) % n);
    a += q.x * w.y - w.x * q.y;
  }
  return a / 2;
}

// Moves every edge inwards by d (outwards if d < 0). null if it collapses.
ArrayList<PVector> insetPoly(ArrayList<PVector> src, float d) {
  ArrayList<PVector> p = new ArrayList<PVector>();
  for (PVector q : src) {
    if (p.size() == 0 || PVector.dist(q, p.get(p.size() - 1)) > 0.01) p.add(q);
  }
  if (p.size() > 1 && PVector.dist(p.get(0), p.get(p.size() - 1)) <= 0.01) p.remove(p.size() - 1);
  int n = p.size();
  if (n < 3) return null;
  float area = signedArea(p);
  if (abs(area) < 0.01) return null;
  float sg = area > 0 ? 1 : -1;

  PVector c = polyCenter(p);
  ArrayList<PVector> out = new ArrayList<PVector>();
  for (int i = 0; i < n; i++) {
    PVector prev = p.get((i - 1 + n) % n), cur = p.get(i), next = p.get((i + 1) % n);
    PVector e1 = PVector.sub(cur, prev).normalize();
    PVector e2 = PVector.sub(next, cur).normalize();
    PVector n1 = new PVector(-e1.y * sg, e1.x * sg);   // inward normals
    PVector n2 = new PVector(-e2.y * sg, e2.x * sg);
    PVector bis = PVector.add(n1, n2);
    if (bis.mag() < 1e-4) bis = n1.copy();
    bis.normalize();
    float off = d / max(0.3, bis.dot(n1));
    if (d > 0) off = min(off, PVector.dist(cur, c) * 0.6);
    out.add(PVector.add(cur, PVector.mult(bis, off)));
  }
  float a2 = signedArea(out);
  if (d > 0 && a2 * sg <= 0) return null;
  return out;
}
