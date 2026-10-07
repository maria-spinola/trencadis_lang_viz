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
  float[] sheen;       // per-vertex glaze sheen 0..1
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
    u   = (cellH - rib) * map(abstraction, 1, 7, 0.17, 0.34);
    quadProb = CUT_STYLE[phen - 1][0];
    jit      = CUT_STYLE[phen - 1][1] * map(organic, 1, 7, 0.7, 1.3);

    makePalette(col, band);
    if (phen >= 3) tex = paint();

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
    float h0 = hue(col);
    float s0 = constrain(saturation(col), 0, 78);
    float b0 = constrain(brightness(col), 45, 90);
    cBase  = new float[] { h0, s0, b0 };
    cLight = new float[] { lerpAngle(h0, 45, 0.35), s0 * 0.16, 95 };   // warm white glaze, a hint of the colour
    cDark  = new float[] { h0, min(85, s0 * 1.1 + 10), b0 * 0.4 };
    float hA = (r.nextFloat() < 0.55) ? h0 + rnd(r, 150, 210)                               // complementary
                                      : h0 + (r.nextBoolean() ? 1 : -1) * rnd(r, 35, 60);  // neighbour
    hA = (hA % 360 + 360) % 360;
    cAcc  = new float[] { hA, constrain(max(s0, 45) + rnd(r, -10, 10), 40, 78), constrain(b0 + rnd(r, -5, 10), 55, 90) };
    cAcc2 = new float[] { lerpAngle(hA, 42, 0.65), 62, 92 };   // ochre / yellow family, like the flower hearts
    if (band >= 0) {
      float[] t = RIBBON_TONES[band % RIBBON_TONES.length];
      cRib = new float[] { lerpAngle(t[0], h0, 0.2), t[1], t[2] };
    } else {
      cRib = new float[] { h0, min(80, s0 + 10), b0 * 0.45 };
    }

    float[] white = { (h0 + 30) % 360, 6, 92 };   // white crockery
    if (phen == 1) {
      // One colour family
      tones = new float[][] {
        { h0, s0, b0 },
        { (h0 + 14) % 360,  s0 * 0.85,          min(b0 * 1.08, 100) },
        { (h0 + 348) % 360, min(s0 * 1.05, 100), b0 * 0.72 },
        { (h0 + 28) % 360,  s0 * 0.6,           min(b0 + 12, 100) },
        { h0,               s0 * 0.95,          b0 * 0.5 },
        white };
    } else {
      // Shards of several plain tiles mixed together
      tones = new float[][] { cBase, cLight, cDark, cAcc, cAcc2, white };
    }
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

  PImage paint() {
    // Enough pixels for the biggest size it is shown at (on the main wall), never more than needed
    int TW = constrain(round(W * RENDER_SCALE * TEXTURE_DETAIL), 128, 1400), TH = max(16, round(TW * H / W));
    PGraphics g = createGraphics(TW, TH, JAVA2D);
    g.beginDraw();
    g.colorMode(HSB, 360, 100, 100, 100);
    g.scale(TW / W);
    switch (phen) {
      case 3:  paintSpiral(g);   break;   // spiral       → spiral bands
      case 4:  paintFlowers(g);  break;   // sub-clusters → scattered flowers and leaves
      case 5:  paintTilework(g); break;   // vibration    → fine geometric tilework
      case 6:  paintWaves(g);    break;   // drift        → arabesque bands
      default: paintChecker(g);           // 3 groupings  → bold two-colour geometry
    }
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

  // Spiral bands winding out from an off-centre point
  void paintSpiral(PGraphics g) {
    g.background(cLight[0], cLight[1], cLight[2]);
    mottle(g, cLight, 10, 12);
    float cx = W * rnd(r, 0.25, 0.75), cy = rib + CH * rnd(r, 0.3, 0.8);
    float reach = dist(0, 0, W, H) * 1.1;
    int   arms  = 2 + r.nextInt(2);
    float pitch = u * rnd(r, 1.6, 2.4) * arms;        // distance between turns of the same arm
    float band  = pitch / arms * 0.55;
    float dir   = r.nextBoolean() ? 1 : -1;
    float a0    = rnd(r, 0, TWO_PI);
    float[][] cols = { cBase, cAcc, cAcc2 };
    g.noFill();
    for (int k = 0; k < arms; k++) {
      float[] c = cols[k % cols.length];
      for (int pass = 0; pass < 2; pass++) {
        if (pass == 0) { strokeC(g, c, 100);    g.strokeWeight(band); }
        else           { strokeC(g, cDark, 70); g.strokeWeight(u * 0.05); }
        g.beginShape();
        for (float t = 0; t < reach / pitch * TWO_PI; t += 0.05) {
          float rad = pitch * t / TWO_PI + (pass == 1 ? band * 0.5 : 0);
          float a = dir * t + a0 + k * TWO_PI / arms;
          g.vertex(cx + cos(a) * rad, cy + sin(a) * rad);
        }
        g.endShape();
      }
    }
    g.noStroke();
    fillC(g, cDark, 100);
    g.ellipse(cx, cy, band * 1.2, band * 1.2);
  }

  void paintFlowers(PGraphics g) {
    float[] ground = vary(cLight, 4, 4, 2);
    g.background(ground[0], ground[1], ground[2]);
    mottle(g, cBase, 8, 14);
    float[] leaf = { lerpAngle(cBase[0], 110, 0.5), min(55, cBase[1] + 10), 60 };
    g.noStroke();
    for (int i = 0; i < 8; i++) {
      fillC(g, vary(leaf, 8, 8, 8), 90);
      g.pushMatrix();
      g.translate(rnd(r, 0, W), rib + rnd(r, 0, CH));
      g.rotate(rnd(r, 0, TWO_PI));
      g.ellipse(0, 0, u * 1.3, u * 0.45);
      g.popMatrix();
    }
    int nF = 2 + r.nextInt(3);
    for (int f = 0; f < nF; f++) {
      float x = W * rnd(r, 0.15, 0.85), y = rib + CH * rnd(r, 0.2, 0.8);
      float fr = u * rnd(r, 1.1, 1.7);
      int   nP = 5 + r.nextInt(2);
      float a0 = rnd(r, 0, TWO_PI);
      for (int i = 0; i < nP; i++) {
        float a = a0 + i * TWO_PI / nP;
        g.pushMatrix();
        g.translate(x, y);
        g.rotate(a);
        fillC(g, vary(cAcc, 4, 6, 8), 100);
        strokeC(g, cDark, 45);
        g.strokeWeight(u * 0.03);
        g.ellipse(fr * 0.5, 0, fr * 0.95, fr * 0.62);
        g.popMatrix();
      }
      g.noStroke();
      fillC(g, cAcc2, 100);
      g.ellipse(x, y, fr * 0.55, fr * 0.55);
      fillC(g, cDark, 70);
      for (int i = 0; i < 7; i++) {
        float a = TWO_PI * i / 7;
        g.ellipse(x + cos(a) * fr * 0.13, y + sin(a) * fr * 0.13, fr * 0.06, fr * 0.06);
      }
    }
  }

  // Fine geometric tilework: diamonds with a small square inside, dark corner triangles
  void paintTilework(PGraphics g) {
    g.background(cLight[0], cLight[1], cLight[2]);
    mottle(g, cLight, 8, 10);
    float m = u * rnd(r, 1.0, 1.4);
    float ox = rnd(r, 0, m), oy = rib + rnd(r, 0, m);
    g.noStroke();
    for (float x = ox - m; x < W + m; x += m) {
      for (float y = oy - m; y < H + m; y += m) {
        float h = m / 2;
        fillC(g, cDark, 85);                               // corner triangles
        g.triangle(x - h, y - h, x - h + m * 0.22, y - h, x - h, y - h + m * 0.22);
        g.triangle(x + h, y + h, x + h - m * 0.22, y + h, x + h, y + h - m * 0.22);
        fillC(g, cBase, 100);                              // diamond
        g.quad(x, y - h * 0.82, x + h * 0.82, y, x, y + h * 0.82, x - h * 0.82, y);
        fillC(g, cAcc, 100);                               // small square
        g.rect(x - m * 0.12, y - m * 0.12, m * 0.24, m * 0.24);
      }
    }
    g.noFill();
    strokeC(g, cAcc2, 45);
    g.strokeWeight(u * 0.025);
    for (float x = ox - m/2; x < W + m; x += m) g.line(x, 0, x, H);
    for (float y = oy - m/2; y < H + m; y += m) g.line(0, y, W, y);
  }

  void paintWaves(PGraphics g) {
    g.background(cLight[0], cLight[1], cLight[2]);
    mottle(g, cLight, 8, 10);
    g.pushMatrix();
    g.translate(W / 2, rib + CH / 2);
    g.rotate(rnd(r, -0.5, 0.5));
    float span = dist(0, 0, W, CH);
    float gap = u * rnd(r, 1.3, 1.9), A = u * rnd(r, 0.3, 0.6), f = TWO_PI / (u * rnd(r, 3, 5));
    float ph = rnd(r, 0, TWO_PI);
    int k = 0;
    for (float y0 = -span; y0 < span; y0 += gap) {
      float[] c = (k % 2 == 0) ? cBase : cAcc;
      g.noFill();
      strokeC(g, c, 100);
      g.strokeWeight(gap * 0.42);
      g.beginShape();
      for (float x = -span; x <= span; x += u * 0.2) g.vertex(x, y0 + A * sin(x * f + ph + k));
      g.endShape();
      strokeC(g, cDark, 70);
      g.strokeWeight(u * 0.05);
      g.beginShape();
      for (float x = -span; x <= span; x += u * 0.2) g.vertex(x, y0 + A * sin(x * f + ph + k) + gap * 0.25);
      g.endShape();
      g.noStroke();
      fillC(g, cAcc2, 95);
      for (float x = -span + rnd(r, 0, u); x < span; x += u * 1.6) {
        float y = y0 + A * sin(x * f + ph + k) - gap * 0.32;
        g.pushMatrix();
        g.translate(x, y);
        g.rotate(atan(A * f * cos(x * f + ph + k)));
        g.ellipse(0, 0, u * 0.5, u * 0.2);
        g.popMatrix();
      }
      k++;
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

    // Neighbouring shards never share a tone
    int[] tone = new int[pieces.size()];
    PVector[] cen = new PVector[pieces.size()];
    for (int i = 0; i < pieces.size(); i++) {
      cen[i] = polyCenter(pieces.get(i));
      IntList avoid = new IntList();
      for (int j = 0; j < i; j++) if (PVector.dist(cen[i], cen[j]) < u * 1.3) avoid.append(tone[j]);
      tone[i] = pickTone(avoid.array());
      float[] col = (tex != null) ? new float[] { 0, 0, rnd(r, 88, 100) }   // painted: each shard glazed a touch differently
                                  : vary(tones[tone[i]], 3, 4, 5);
      addPiece(pieces.get(i), col, tex != null);
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
    if (painted) {
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

    pc.sheen = new float[n];
    float pr = 1;
    for (int i = 0; i < n; i++) pr = max(pr, dist(pc.x[i], pc.y[i], pc.cx, pc.cy));
    for (int i = 0; i < n; i++) {
      pc.sheen[i] = max(0, ((pc.x[i] - pc.cx) * LIGHT_X + (pc.y[i] - pc.cy) * LIGHT_Y) / pr);
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
    if (withGrout) drawBed(pg, alpha);
    for (Piece p : pieces) drawPiece(pg, p, alpha, 0, 0);
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
    drawBed(pg, alpha * smooth01(t / 0.45), dry);
    for (Piece p : pieces) drawPiece(pg, p, alpha, 0, 0);
  }

  void drawBed(PGraphics pg, float alpha) { drawBed(pg, alpha, 1); }

  void drawBed(PGraphics pg, float alpha, float dry) {
    if (alpha <= 0) return;
    pg.fill(GROUT_H, lerp(min(100, GROUT_S + 12), GROUT_S, dry), lerp(GROUT_B * 0.45, GROUT_B, dry), alpha);
    pg.beginShape();
    for (int i = 0; i < gx.length; i++) pg.vertex(gx[i], gy[i]);
    pg.endShape(CLOSE);
  }

  void drawPiece(PGraphics pg, Piece p, float alpha, float ox, float oy) { drawPiece(pg, p, alpha, ox, oy, 1); }

  // dim < 1 darkens the piece (far away while assembling)
  void drawPiece(PGraphics pg, Piece p, float alpha, float ox, float oy, float dim) {
    pg.beginShape();
    if (p.u != null) {
      pg.texture(tex);
      pg.tint(0, 0, p.b * dim, alpha);
      for (int i = 0; i < p.x.length; i++) pg.vertex(p.x[i] - ox, p.y[i] - oy, p.u[i], p.v[i]);
    } else {
      pg.fill(p.h, p.s, p.b * dim, alpha);
      for (int i = 0; i < p.x.length; i++) pg.vertex(p.x[i] - ox, p.y[i] - oy);
    }
    pg.endShape(CLOSE);
    pg.noTint();

    // Very soft sheen of the glaze towards the light
    if (GLAZE <= 0) return;
    pg.beginShape();
    for (int i = 0; i < p.x.length; i++) {
      pg.fill(0, 0, 100, alpha * dim * GLAZE / 100 * p.sheen[i]);
      pg.vertex(p.x[i] - ox, p.y[i] - oy);
    }
    pg.endShape(CLOSE);
  }
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
