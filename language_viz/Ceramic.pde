// ═══════════════════════════════════════════════════════════
// Ceramic.pde
// Makes each tile look like real trencadís (Park Güell benches).
// Once, when the tile is made, every pixel is "baked": each shard
// as a piece of glazed ceramic sitting slightly tilted in the
// mortar, lit from the upper left, and the lime mortar around it.
//
//   shard   tilt in the mortar · glaze surface not quite flat
//           (orange peel, pools darker in the hollows) · reflection
//           of a bright sky on the gloss · narrow rounded edge
//           catching the light · edge not perfectly straight ·
//           chips where the glaze flaked off and the fired clay
//           shows · marbled glaze (jaspeado) on some plain tiles ·
//           a few shards of moulded relief tiles (leaves and
//           berries) · the ribbon on top as a round glazed moulding
//           · gold lustre that reflects like metal
//   mortar  warm lime, sand grains and stains, darker right next
//           to the shards (they stand a little proud) and a short
//           contact shadow on the side away from the light
//
// The result is two images per tile (TrencadisTile.bakeAll /
// bakeShards); drawing them is cheaper than the old layered relief.
// Settings: "Ceramic look" in Config.pde, colours in Colors.pde.
// ═══════════════════════════════════════════════════════════

float bakeDetailK = 1;   // × TEXTURE_DETAIL: lower while restoring the mural or for poem tiles (Mosaic, WordsSystem)

// ── Value noise (a fixed 256 × 256 table, smooth between its points) ──

float[] VN;

void initCeramicNoise() {
  VN = new float[256 * 256];
  Random r = new Random(12345);
  for (int i = 0; i < VN.length; i++) VN[i] = r.nextFloat();
}

float vn(float x, float y) {
  int xi = (int) Math.floor(x), yi = (int) Math.floor(y);
  float fx = x - xi, fy = y - yi;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  int x0 = xi & 255, y0 = yi & 255, x1 = (x0 + 1) & 255, y1 = (y0 + 1) & 255;
  float a = VN[y0 * 256 + x0], b = VN[y0 * 256 + x1], c = VN[y1 * 256 + x0], d = VN[y1 * 256 + x1];
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

// The same noise, but straight between its points: a warp made of straight runs and kinks
float vnLin(float x, float y) {
  int xi = (int) Math.floor(x), yi = (int) Math.floor(y);
  float fx = x - xi, fy = y - yi;
  int x0 = xi & 255, y0 = yi & 255, x1 = (x0 + 1) & 255, y1 = (y0 + 1) & 255;
  float a = VN[y0 * 256 + x0], b = VN[y0 * 256 + x1], c = VN[y1 * 256 + x0], d = VN[y1 * 256 + x1];
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

float fbm(float x, float y) {
  return 0.5 * vn(x, y) + 0.3 * vn(x * 2.03 + 17.1, y * 2.03 + 9.3) + 0.2 * vn(x * 4.11 + 5.7, y * 4.11 + 31.9);
}

// Per-pixel grain, 0..1
float hash01(int x, int y, int s) {
  int h = x * 374761393 + y * 668265263 + s * 982451653;
  h = (h ^ (h >>> 13)) * 1274126177;
  h ^= h >>> 16;
  return (h & 0xFFFF) / 65535.0;
}

float sstep(float e0, float e1, float x) {
  float t = constrain((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
}

float[] rgbOf(float h, float s, float b) {
  int c = java.awt.Color.HSBtoRGB(((h % 360) + 360) % 360 / 360f, constrain(s, 0, 100) / 100f, constrain(b, 0, 100) / 100f);
  return new float[] { ((c >> 16) & 255) / 255f, ((c >> 8) & 255) / 255f, (c & 255) / 255f };
}

float[] rgbOfHex(String hex) {
  int c = hexColor(hex);
  return new float[] { ((c >> 16) & 255) / 255f, ((c >> 8) & 255) / 255f, (c & 255) / 255f };
}

// ── Moulded relief tile (rajola de relleu): a raised frame, four leaves with their veins
//    and a bunch of berries. u, v in −1..1 over the source tile; height 0..1 ──

float[] BERRY_X, BERRY_Y;

float reliefHeight(float u, float v) {
  if (BERRY_X == null) {
    BERRY_X = new float[13]; BERRY_Y = new float[13];
    Random r = new Random(77);
    for (int i = 0; i < 13; i++) {
      float a = i * 2.39996, d = 0.075 * sqrt(i + 0.5) * 1.55;
      BERRY_X[i] = 0.05 + cos(a) * d + (r.nextFloat() - 0.5) * 0.02;
      BERRY_Y[i] = 0.02 + sin(a) * d * 1.15 + (r.nextFloat() - 0.5) * 0.02;
    }
  }
  float fr = max(abs(u), abs(v));
  float h = 0.5 * sstep(0.80, 0.86, fr) * (1 - sstep(0.94, 0.99, fr));   // raised frame
  for (int i = 0; i < 4; i++) {                                         // leaves
    float a = i * HALF_PI + 0.7, ca = cos(a), sa = sin(a);
    float lx = u - ca * 0.45, ly = v - sa * 0.45;
    float lu = lx * ca + ly * sa, lv = -lx * sa + ly * ca;
    float e = sq(lu / 0.36) + sq(lv / (0.17 * (1 - 0.5 * max(0, lu / 0.36)))) ;
    if (e < 1) {
      float hl = 0.42 * sqrt(1 - e);
      hl -= 0.09 * exp(-sq(lv / 0.022));                                   // the midrib
      float vein = (lu * 7 + abs(lv) * 6) % 1;
      hl -= 0.05 * exp(-sq((vein - 0.5) / 0.1)) * (1 - e);                // side veins
      h = max(h, hl);
    }
  }
  for (int i = 0; i < BERRY_X.length; i++) {                            // berries
    float d2 = sq(u - BERRY_X[i]) + sq(v - BERRY_Y[i]), rr = 0.105;
    if (d2 < rr * rr) h = max(h, 0.32 + 0.6 * sqrt(1 - d2 / (rr * rr)));
  }
  return h;
}

// ── The bake ──────────────────────────────────────────────────

void bakeCeramic(TrencadisTile t) {
  if (VN == null) initCeramicNoise();
  int np = t.pieces.size();
  if (np == 0) return;

  // Area of the images: the mortar bed, plus a margin
  float x0 = Float.MAX_VALUE, y0 = Float.MAX_VALUE, x1 = -Float.MAX_VALUE, y1 = -Float.MAX_VALUE;
  for (int i = 0; i < t.gx.length; i++) { x0 = min(x0, t.gx[i]); x1 = max(x1, t.gx[i]); y0 = min(y0, t.gy[i]); y1 = max(y1, t.gy[i]); }
  for (Piece p : t.pieces) for (int i = 0; i < p.x.length; i++) { x0 = min(x0, p.x[i]); x1 = max(x1, p.x[i]); y0 = min(y0, p.y[i]); y1 = max(y1, p.y[i]); }
  x0 -= 2; y0 -= 2; x1 += 2; y1 += 2;
  float k = RENDER_SCALE * TEXTURE_DETAIL * bakeDetailK;   // pixels per tile unit
  k = min(k, BAKE_MAX_PX / max(x1 - x0, y1 - y0));
  int w = max(4, ceil((x1 - x0) * k)), h = max(4, ceil((y1 - y0) * k));
  t.bakeX0 = x0; t.bakeY0 = y0; t.bakeW = w / k; t.bakeH = h / k;
  int N = w * h;

  // ── 1. Which shard covers each pixel, how far from its edge; distance to the shards for the mortar ──
  int[] id = new int[N];
  float[] de = new float[N], da = new float[N], sh = new float[N];
  byte[] eg = new byte[N];
  java.util.Arrays.fill(id, -1);
  java.util.Arrays.fill(da, 1e9f);
  float lx = LIGHT_X, ly = LIGHT_Y;
  float shX = -lx * SHADOW_LEN, shY = -ly * SHADOW_LEN;   // the contact shadow falls away from the light
  float reach = max(AO_RADIUS * 3, SHADOW_LEN + 1.5);

  // per shard: its edges (start point, direction, inward normal)
  float[][] EX = new float[np][], EY = new float[np][], DX = new float[np][], DY = new float[np][], NX = new float[np][], NY = new float[np][];
  for (int pi = 0; pi < np; pi++) {
    Piece p = t.pieces.get(pi);
    int n = p.x.length;
    float area = 0;
    for (int i = 0; i < n; i++) { int j = (i + 1) % n; area += p.x[i] * p.y[j] - p.x[j] * p.y[i]; }
    float sg = area > 0 ? 1 : -1;
    EX[pi] = new float[n]; EY[pi] = new float[n]; DX[pi] = new float[n]; DY[pi] = new float[n]; NX[pi] = new float[n]; NY[pi] = new float[n];
    float bx0 = Float.MAX_VALUE, by0 = Float.MAX_VALUE, bx1 = -Float.MAX_VALUE, by1 = -Float.MAX_VALUE;
    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      float ex = p.x[j] - p.x[i], ey = p.y[j] - p.y[i], l = max(1e-4, sqrt(ex * ex + ey * ey));
      EX[pi][i] = p.x[i]; EY[pi][i] = p.y[i];
      DX[pi][i] = ex / l; DY[pi][i] = ey / l;
      NX[pi][i] = -ey / l * sg; NY[pi][i] = ex / l * sg;    // inward
      bx0 = min(bx0, p.x[i]); bx1 = max(bx1, p.x[i]); by0 = min(by0, p.y[i]); by1 = max(by1, p.y[i]);
    }
    int ix0 = max(0, floor((bx0 - reach - x0) * k)), ix1 = min(w - 1, ceil((bx1 + reach - x0) * k));
    int iy0 = max(0, floor((by0 - reach - y0) * k)), iy1 = min(h - 1, ceil((by1 + reach - y0) * k));
    float[] px_ = p.x, py_ = p.y;
    for (int iy = iy0; iy <= iy1; iy++) {
      float Y = y0 + (iy + 0.5) / k;
      for (int ix = ix0; ix <= ix1; ix++) {
        float X = x0 + (ix + 0.5) / k;
        int q = iy * w + ix;
        // signed distance to the shard's outline (any shape): + inside, − outside; and the nearest edge
        float dmin = 1e9; int emin = 0; boolean in = false;
        for (int e = 0, f = n - 1; e < n; f = e, e++) {
          if (((py_[e] > Y) != (py_[f] > Y)) && (X < (px_[f] - px_[e]) * (Y - py_[e]) / (py_[f] - py_[e]) + px_[e])) in = !in;
        }
        for (int e = 0; e < n; e++) {
          int j = (e + 1) % n;
          float sx = px_[j] - px_[e], sy = py_[j] - py_[e], l2 = max(1e-6, sx * sx + sy * sy);
          float tt = constrain(((X - px_[e]) * sx + (Y - py_[e]) * sy) / l2, 0, 1);
          float d = dist(X, Y, px_[e] + sx * tt, py_[e] + sy * tt);
          if (d < dmin) { dmin = d; emin = e; }
        }
        if (in) {
          if (id[q] < 0 || dmin > de[q]) { id[q] = pi; de[q] = dmin; eg[q] = (byte) emin; }
          da[q] = 0;
        } else {
          if (dmin < da[q]) da[q] = dmin;
          if (CONTACT_SHADOW > 0 && dmin < SHADOW_LEN + 1.5) {
            // is this point under the shard, seen from the light? (the shard moved towards the light)
            float Xs = X - shX, Ys = Y - shY; boolean in2 = false; float d2 = 1e9;
            for (int e = 0, f = n - 1; e < n; f = e, e++) {
              if (((py_[e] > Ys) != (py_[f] > Ys)) && (Xs < (px_[f] - px_[e]) * (Ys - py_[e]) / (py_[f] - py_[e]) + px_[e])) in2 = !in2;
              float sx = px_[e] - px_[f], sy = py_[e] - py_[f], l2 = max(1e-6, sx * sx + sy * sy);
              float tt = constrain(((Xs - px_[f]) * sx + (Ys - py_[f]) * sy) / l2, 0, 1);
              d2 = min(d2, dist(Xs, Ys, px_[f] + sx * tt, py_[f] + sy * tt));
            }
            float s = sstep(-0.8, 0.6, in2 ? d2 : -d2);
            if (s > sh[q]) sh[q] = s;
          }
        }
      }
    }
  }

  // ── 2. What each shard is made of ──
  Random tr = new Random(t.seed * 977 + 5);
  float[] body = rgbOfHex(tr.nextFloat() < 0.6 ? BODY_TERRACOTTA : BODY_CREAM);   // the fired clay under the glaze
  float[] grout = rgbOfHex(GROUT_COLOR), sky = rgbOfHex(SKY_REFLECTION), gold = rgbOfHex(GOLD_LUSTRE_COLOR);
  float[][] base = new float[np][];
  float[][] aff = new float[np][];            // painted shards: tile units → texture (u, v)
  boolean[] marble = new boolean[np], relief = new boolean[np], crackle = new boolean[np];
  float[] cabX = new float[np], cabY = new float[np], cabR = new float[np], crS = new float[np];
  float[] mAng = new float[np], mFreq = new float[np], rS = new float[np], rCx = new float[np], rCy = new float[np], rAng = new float[np];
  float[][] mVein = new float[np][], rGlaze = new float[np][];
  float[] nOffX = new float[np], nOffY = new float[np];
  int[] texPx = null; int texW = 0, texH = 0;
  if (t.tex != null) { t.tex.loadPixels(); texPx = t.tex.pixels; texW = t.tex.width; texH = t.tex.height; }
  for (int pi = 0; pi < np; pi++) {
    Piece p = t.pieces.get(pi);
    Random pr = new Random(t.seed * 31 + pi * 7919 + 1);
    Random sr = new Random(t.seed * 17 + p.src * 104729L + 3);   // the same for every shard of one source tile
    base[pi] = (p.kind == KIND_GOLD) ? gold : rgbOf(p.h, p.s, p.b);
    nOffX[pi] = pr.nextFloat() * 200; nOffY[pi] = pr.nextFloat() * 200;
    if (p.u != null && texPx != null) {
      // affine map from three well-spread corners
      int n = p.x.length, a = 0, b = 1, c = 2; float best = -1;
      for (int i = 1; i < n; i++) for (int j = i + 1; j < n; j++) {
        float ar = abs((p.x[i] - p.x[0]) * (p.y[j] - p.y[0]) - (p.x[j] - p.x[0]) * (p.y[i] - p.y[0]));
        if (ar > best) { best = ar; b = i; c = j; }
      }
      float det = (p.x[b] - p.x[a]) * (p.y[c] - p.y[a]) - (p.x[c] - p.x[a]) * (p.y[b] - p.y[a]);
      if (abs(det) > 1e-6) {
        float[] m = new float[6];
        for (int o = 0; o < 2; o++) {
          float[] val = (o == 0) ? p.u : p.v;
          float da_ = val[b] - val[a], db_ = val[c] - val[a];
          float A = (da_ * (p.y[c] - p.y[a]) - db_ * (p.y[b] - p.y[a])) / det;
          float B = (db_ * (p.x[b] - p.x[a]) - da_ * (p.x[c] - p.x[a])) / det;
          m[o * 3] = A; m[o * 3 + 1] = B; m[o * 3 + 2] = val[a] - A * p.x[a] - B * p.y[a];
        }
        aff[pi] = m;
      }
    }
    boolean plain = (p.kind == KIND_TILE && (p.u == null || t.phen == 2)) || p.kind == KIND_OTHER;
    if (plain && sr.nextFloat() < MARBLE_SHARE) {
      marble[pi] = true;
      mAng[pi] = sr.nextFloat() * PI;
      mFreq[pi] = 0.05 + sr.nextFloat() * 0.07;
      float[] c0 = base[pi];
      mVein[pi] = new float[] { lerp(c0[0], 0.95, 0.75), lerp(c0[1], 0.92, 0.75), lerp(c0[2], 0.86, 0.75) };
    }
    if (plain && !marble[pi] && sr.nextFloat() < CRACKLE_SHARE) { crackle[pi] = true; crS[pi] = 3.5 + sr.nextFloat() * 4; }   // craquelure
    if (p.kind == KIND_GLASS && GLASS_BOTTLES && p.area > sq(t.refH * 0.14) && pr.nextFloat() < 0.65) {
      // a round bottle bottom set in this glass shard, as big as fits
      float inr = 1e9;
      for (int e = 0; e < EX[pi].length; e++) inr = min(inr, (p.cx - EX[pi][e]) * NX[pi][e] + (p.cy - EY[pi][e]) * NY[pi][e]);
      if (inr > 4) { cabX[pi] = p.cx; cabY[pi] = p.cy; cabR[pi] = inr * 0.82; }
    }
    float relChance = (p.kind == KIND_OTHER) ? RELIEF_TILE_SHARE_OTHER : (p.kind == KIND_TILE ? RELIEF_TILE_SHARE : 0);
    if (p.area > sq(t.refH * 0.12) && pr.nextFloat() < relChance) {
      relief[pi] = true;
      rS[pi] = max(30, sqrt(p.area) * pr.nextFloat() * 1.2 + sqrt(p.area) * 1.3);   // size of the source relief tile
      rCx[pi] = p.cx + (pr.nextFloat() - 0.5) * rS[pi] * 0.6;
      rCy[pi] = p.cy + (pr.nextFloat() - 0.5) * rS[pi] * 0.6;
      rAng[pi] = HALF_PI * pr.nextInt(4) + (pr.nextFloat() - 0.5) * 0.3;
      rGlaze[pi] = rgbOfHex(RELIEF_GLAZES[pr.nextInt(RELIEF_GLAZES.length)]);
    }
  }

  // ── 3. Light every pixel ──
  float Lz = 1.25, Ln = sqrt(lx * lx + ly * ly + Lz * Lz);
  float Lx = lx / Ln, Ly = ly / Ln, Lzz = Lz / Ln;
  float Hx = Lx, Hy = Ly, Hz = Lzz + 1, Hn = sqrt(Hx * Hx + Hy * Hy + Hz * Hz);
  Hx /= Hn; Hy /= Hn; Hz /= Hn;
  float KA = 0.42, KD = 0.58, flat = KA + KD * Lzz;
  float tilt = tan(radians(SHARD_TILT_DEG)) * RELIEF;
  int[] all = new int[N], shards = new int[N], gloss = new int[N];
  float gsx = (t.seed % 997) * 0.37, gsy = (t.seed % 991) * 0.53;

  for (int iy = 0; iy < h; iy++) {
    float Y = y0 + (iy + 0.5) / k;
    for (int ix = 0; ix < w; ix++) {
      float X = x0 + (ix + 0.5) / k;
      int q = iy * w + ix;

      // the mortar here (also under the rough edge of a shard)
      float stain = fbm(X * 0.035 + gsx, Y * 0.035 + gsy);
      float g = hash01(ix, iy, 1), g2 = hash01(ix, iy, 2);
      float m = (0.9 + 0.16 * stain) * (0.94 + 0.12 * g);
      if (g2 < 0.03) m *= 0.72; else if (g2 > 0.985) m *= 1.07;           // dark and light grains of sand
      float near = (id[q] >= 0) ? 0 : da[q];
      m *= 1 - AO_STRENGTH * RELIEF * (float) Math.exp(-near / max(0.2, AO_RADIUS));   // darker against the shards
      m *= 1 - CONTACT_SHADOW * RELIEF * sh[q];
      float mr = grout[0] * m, mg = grout[1] * m, mb = grout[2] * m;

      int pi = id[q];
      if (pi < 0) {
        all[q] = argb(1, mr, mg, mb);
        shards[q] = 0;
        continue;
      }
      Piece p = t.pieces.get(pi);
      int e = eg[q];
      float d = de[q];
      float along = (X - EX[pi][e]) * DX[pi][e] + (Y - EY[pi][e]) * DY[pi][e];
      float rough = EDGE_ROUGH * (0.65 * vn(along * 0.28 + pi * 13.1, e * 7.3 + 3.1 + pi) + 0.35 * vn(along * 0.9 + pi * 5.3, e * 2.1 + 9.7));   // broken edges wander
      float dd = d - rough;
      float cov = constrain(dd * k + 0.5, 0, 1);                          // the broken edge, a little ragged
      boolean chip = false;
      if (p.chipped != null && e < p.chipped.length && p.chipped[e]) {
        float bite = CHIP_DEPTH * sstep(0.62, 0.92, vn(along * 0.09 + pi * 3.7, e * 5.1 + 11))    // a few shell-shaped bites
                   * (0.7 + 0.6 * vn(along * 0.5 + pi, e * 3.3));
        chip = dd < bite;
      }

      // ── surface normal ──
      float nx = p.tiltX * tilt, ny = p.tiltY * tilt, nz = 1;
      float ox = nOffX[pi], oy = nOffY[pi];
      // the glaze is not flat glass: long gentle waves where it pooled, and a faint orange peel
      float uf = 1.0 / 40, pf = 1.0 / 7;
      float hU = fbm(X * uf + ox, Y * uf + oy);
      float gxu = (fbm((X + 2) * uf + ox, Y * uf + oy) - fbm((X - 2) * uf + ox, Y * uf + oy)) * 0.25;
      float gyu = (fbm(X * uf + ox, (Y + 2) * uf + oy) - fbm(X * uf + ox, (Y - 2) * uf + oy)) * 0.25;
      float gxp = (vn((X + 1) * pf + oy, Y * pf + ox) - vn((X - 1) * pf + oy, Y * pf + ox)) * 0.5;
      float gyp = (vn(X * pf + oy, (Y + 1) * pf + ox) - vn(X * pf + oy, (Y - 1) * pf + ox)) * 0.5;
      nx -= (gxu * 1.1 + gxp * 0.06) * UNDULATION; ny -= (gyu * 1.1 + gyp * 0.06) * UNDULATION;
      float tR = 0;
      if (dd < RIM_WIDTH) {                                                 // the edge rolls over
        tR = 1 - max(0, dd) / RIM_WIDTH;
        float bend = RIM_BEND * RELIEF * tR * tR;
        nx -= NX[pi][e] * bend; ny -= NY[pi][e] * bend;
      }
      if (p.kind == KIND_RIBBON && p.rib > 0) {                             // round moulding along the top
        float ax = p.bx - p.ax, ay = p.by - p.ay, al = max(1e-4, sqrt(ax * ax + ay * ay));
        float ndx = -ay / al, ndy = ax / al;
        if ((p.cx - p.ax) * ndx + (p.cy - p.ay) * ndy < 0) { ndx = -ndx; ndy = -ndy; }   // pointing down, into the tile
        float tc = constrain(((X - p.ax) * ndx + (Y - p.ay) * ndy) / p.rib, 0, 1);
        float th_ = lerp(-0.85, 0.85, tc) * RELIEF;
        nx += ndx * sin(th_); ny += ndy * sin(th_); nz = cos(th_);
      }
      float hr = 0;
      if (relief[pi]) {                                                     // moulded relief tile
        float ca = cos(rAng[pi]), sa = sin(rAng[pi]), half = rS[pi] * 0.5;
        float rx = X - rCx[pi], ry = Y - rCy[pi];
        float u = (rx * ca + ry * sa) / half, v = (-rx * sa + ry * ca) / half;
        float ee = 0.012;
        hr = reliefHeight(u, v);
        float du = (reliefHeight(u + ee, v) - reliefHeight(u - ee, v)) / (2 * ee);
        float dv = (reliefHeight(u, v + ee) - reliefHeight(u, v - ee)) / (2 * ee);
        float sc = RELIEF_DEPTH / half;
        float gX = (du * ca - dv * sa) * sc, gY = (du * sa + dv * ca) * sc;
        nx -= gX; ny -= gY;
      }
      float nl = sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nl; ny /= nl; nz /= nl;

      // ── colour of the glaze ──
      float cr, cg, cb;
      if (aff[pi] != null && texPx != null) {
        float wx = X + (vn(X * 0.13 + ox, Y * 0.13) - 0.5) * PAINT_WOBBLE;   // painted by hand: lines wobble a little
        float wy = Y + (vn(X * 0.13, Y * 0.13 + oy) - 0.5) * PAINT_WOBBLE;
        float[] a = aff[pi];
        float tu = (a[0] * wx + a[1] * wy + a[2]) * texW - 0.5, tv = (a[3] * wx + a[4] * wy + a[5]) * texH - 0.5;
        int ux = constrain((int) Math.floor(tu), 0, texW - 1), vy = constrain((int) Math.floor(tv), 0, texH - 1);
        int ux1 = min(texW - 1, ux + 1), vy1 = min(texH - 1, vy + 1);
        float fu = constrain(tu - ux, 0, 1), fv = constrain(tv - vy, 0, 1);
        int c00 = texPx[vy * texW + ux], c10 = texPx[vy * texW + ux1], c01 = texPx[vy1 * texW + ux], c11 = texPx[vy1 * texW + ux1];
        float tint = p.b / 100f;
        cr = bil((c00 >> 16) & 255, (c10 >> 16) & 255, (c01 >> 16) & 255, (c11 >> 16) & 255, fu, fv) / 255f * tint;
        cg = bil((c00 >> 8) & 255, (c10 >> 8) & 255, (c01 >> 8) & 255, (c11 >> 8) & 255, fu, fv) / 255f * tint;
        cb = bil(c00 & 255, c10 & 255, c01 & 255, c11 & 255, fu, fv) / 255f * tint;
      } else {
        cr = base[pi][0]; cg = base[pi][1]; cb = base[pi][2];
      }
      if (marble[pi]) {                                                     // jaspeado: veins in the glaze
        float ca = cos(mAng[pi]), sa = sin(mAng[pi]);
        float mm = sin((X * ca + Y * sa) * mFreq[pi] * TWO_PI * 0.25 + 6 * fbm(X * 0.04 + ox, Y * 0.04 + oy));
        float m2 = sin((X * sa - Y * ca) * mFreq[pi] * TWO_PI * 0.6 + 9 * fbm(X * 0.07 + oy, Y * 0.07 + ox));
        float vein = sstep(0.955, 0.997, mm) * 0.7 + sstep(0.975, 0.999, m2) * 0.35
                   + sstep(0.6, 0.85, fbm(X * 0.08 + oy, Y * 0.08 + ox)) * 0.08;   // fine veins and soft clouds
        float dark = sstep(0.9, 0.995, -mm) * 0.15;
        cr = lerp(cr, mVein[pi][0], vein) * (1 - dark);
        cg = lerp(cg, mVein[pi][1], vein) * (1 - dark);
        cb = lerp(cb, mVein[pi][2], vein) * (1 - dark);
      }
      if (relief[pi]) {                                                     // deep glaze in the hollows, thin on the tops
        float[] gz = rGlaze[pi];
        float deep = sstep(0.0, 0.35, hr), peak = sstep(0.5, 0.92, hr);
        cr = lerp(gz[0] * 0.55, gz[0], deep); cg = lerp(gz[1] * 0.55, gz[1], deep); cb = lerp(gz[2] * 0.55, gz[2], deep);
        cr = lerp(cr, body[0], peak * 0.65); cg = lerp(cg, body[1], peak * 0.65); cb = lerp(cb, body[2], peak * 0.65);
      }
      if (crackle[pi]) {                                                    // craquelure: a fine net of cracks in the glaze
        float cl = crackLine(X / crS[pi] + ox, Y / crS[pi] + oy);
        float k2 = 1 - 0.38 * cl;
        cr *= k2; cg *= k2; cb *= k2 * 0.97;
      }
      if (p.kind == KIND_RIBBON) {                                          // the glazed capping: darker streaks run along it
        float ax2 = p.bx - p.ax, ay2 = p.by - p.ay, al2 = max(1e-4, sqrt(ax2 * ax2 + ay2 * ay2));
        float alongR = ((X - p.ax) * ax2 + (Y - p.ay) * ay2) / al2, acrossR = (-(X - p.ax) * ay2 + (Y - p.ay) * ax2) / al2;
        float st = fbm(alongR * 0.025 + ox, acrossR * 0.22 + oy);
        float dk = sstep(0.5, 0.72, st) * 0.45;
        cr *= 1 - dk; cg *= 1 - dk * 0.85; cb *= 1 - dk * 0.9;
      }
      float pool = 0.93 + 0.14 * hU;                                        // thicker glaze in the hollows is deeper
      cr *= pool; cg *= pool; cb *= pool;
      if (tR > 0) { float th2 = 0.12 * tR; cr += (1 - cr) * th2; cg += (1 - cg) * th2; cb += (1 - cb) * th2; }   // thin glaze on the edge
      boolean matte = false;
      float gl = 0.55 + 0.4 * tR;                                           // how glossy (the light sweeping the mural)
      if (p.kind == KIND_GLASS) {                                           // coloured glass: deep, glowing where the light comes out
        float[] gc = base[pi];
        float rr = max(4, sqrt(p.area) * 0.5);
        float away = -((X - p.cx) / rr * LIGHT_X + (Y - p.cy) / rr * LIGHT_Y);
        float glow = sstep(-0.4, 1.1, away), thin = 1 - sstep(0, 3.2, dd);
        cr = gc[0] * (0.3 + 0.8 * glow); cg = gc[1] * (0.3 + 0.8 * glow); cb = gc[2] * (0.3 + 0.8 * glow);
        cr = lerp(cr, min(1, mr * (0.4 + gc[0])), thin * 0.45); cg = lerp(cg, min(1, mg * (0.4 + gc[1])), thin * 0.45); cb = lerp(cb, min(1, mb * (0.4 + gc[2])), thin * 0.45);
        if (cabR[pi] > 0) {                                                 // the bottle bottom: a glass dome with its ring
          float dxc = (X - cabX[pi]) / cabR[pi], dyc = (Y - cabY[pi]) / cabR[pi], rc = sqrt(dxc * dxc + dyc * dyc);
          if (rc < 1) {
            float hz = sqrt(1 - rc * rc);
            nx = dxc * 0.85; ny = dyc * 0.85; nz = hz + 0.15;
            nl = sqrt(nx * nx + ny * ny + nz * nz); nx /= nl; ny /= nl; nz /= nl;
            float awayC = -(dxc * LIGHT_X + dyc * LIGHT_Y);
            float lum = 0.25 + 0.6 * sstep(-0.1, 0.9, awayC) * (1 - rc * 0.3) + 0.35 * exp(-sq((rc - 0.42) / 0.07));   // light coming through, the punt's ring
            float rim = sstep(0.86, 1.0, rc);
            cr = gc[0] * lum * (1 - 0.6 * rim) + 0.05; cg = gc[1] * lum * (1 - 0.6 * rim) + 0.05; cb = gc[2] * lum * (1 - 0.6 * rim) + 0.05;
          }
        }
        gl = 1;
      }
      if (chip) {                                                           // glaze flaked off: the fired clay
        float gr = 0.82 + 0.3 * hash01(ix, iy, 5);
        cr = body[0] * gr; cg = body[1] * gr; cb = body[2] * gr;
        nx = (vn(X * 0.9, Y * 0.9) - 0.5) * 0.5 - NX[pi][e] * 0.35; ny = (vn(X * 0.9 + 9, Y * 0.9) - 0.5) * 0.5 - NY[pi][e] * 0.35; nz = 1;
        nl = sqrt(nx * nx + ny * ny + 1); nx /= nl; ny /= nl; nz /= nl;
        matte = true;
        gl = 0;
      }

      // ── light ──
      float ndl = max(0, nx * Lx + ny * Ly + nz * Lzz);
      float diff = (KA + KD * ndl) / flat;
      float r_ = cr * diff, g_ = cg * diff, b_ = cb * diff;
      if (!matte) {
        // reflection of a bright sky above and behind the viewer, with a soft, uneven horizon
        float rx = 2 * nz * nx, ry = 2 * nz * ny;
        float horizon = 0.08 * (vn(rx * 6 + 3.3, 1.7) - 0.5);
        float skyAmt = sstep(0.10, -0.28, ry + 0.3 * rx + horizon);
        float facing = 1 - nz;
        float refl = GLOSS * (0.12 + 0.88 * skyAmt) * (0.5 + 5 * facing);
        float spec = SPECULAR * (float) Math.pow(max(0, nx * Hx + ny * Hy + nz * Hz), 90);
        if (p.kind == KIND_GLASS) {                                         // glass: a sharper, stronger reflection
          float spec2 = SPECULAR * 1.6 * (float) Math.pow(max(0, nx * Hx + ny * Hy + nz * Hz), 160);
          float rg = min(1, refl * 1.6);
          r_ = r_ * (1 - rg * 0.3) + sky[0] * rg * 0.55 + spec2;
          g_ = g_ * (1 - rg * 0.3) + sky[1] * rg * 0.55 + spec2;
          b_ = b_ * (1 - rg * 0.3) + sky[2] * rg * 0.55 + spec2;
        } else if (p.kind == KIND_GOLD) {                                   // lustre: a metallic reflection, golden
          float met = 0.5 + refl * 4.5 + spec * 1.5 + 0.25 * (hU - 0.5);   // bright, with the room's light moving in it
          r_ = r_ * 0.15 + gold[0] * met;
          g_ = g_ * 0.15 + gold[1] * met;
          b_ = b_ * 0.15 + gold[2] * met * 0.9;
        } else {
          refl = min(refl, p.kind == KIND_RIBBON ? 0.45 : 0.85);
          r_ = r_ * (1 - refl * 0.35) + sky[0] * refl * 0.6 + spec;
          g_ = g_ * (1 - refl * 0.35) + sky[1] * refl * 0.6 + spec;
          b_ = b_ * (1 - refl * 0.35) + sky[2] * refl * 0.6 + spec;
        }
      }
      if (p.kind == KIND_GOLD) gl = 1; else if (p.kind == KIND_RIBBON) gl = 0.75;
      gloss[q] = argb(gl * cov, 1, 1, 1);
      shards[q] = argb(cov, r_, g_, b_);
      all[q] = argb(1, lerp(mr, r_, cov), lerp(mg, g_, cov), lerp(mb, b_, cov));
    }
  }

  PImage A = createImage(w, h, ARGB), S = createImage(w, h, ARGB);
  A.loadPixels(); S.loadPixels();
  System.arraycopy(all, 0, A.pixels, 0, N);
  System.arraycopy(shards, 0, S.pixels, 0, N);
  A.updatePixels(); S.updatePixels();
  PImage G = createImage(w, h, ARGB);
  G.loadPixels(); System.arraycopy(gloss, 0, G.pixels, 0, N); G.updatePixels();
  t.bakeGloss = G;
  t.bakeAll = A;
  t.bakeShards = S;
  for (Piece p : t.pieces) {                                                // where each shard is in the images
    int n = p.x.length;
    p.bu = new float[n]; p.bv = new float[n];
    for (int i = 0; i < n; i++) { p.bu[i] = (p.x[i] - x0) / t.bakeW; p.bv[i] = (p.y[i] - y0) / t.bakeH; }
  }
  t.tex = null;   // the painting is in the baked images now
}

// Craquelure: 1 on the thin cracks between irregular cells, 0 elsewhere
float crackLine(float x, float y) {
  int xi = (int) Math.floor(x), yi = (int) Math.floor(y);
  float f1 = 9, f2 = 9;
  for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
    int cx = xi + dx, cy = yi + dy;
    float px = cx + hash01(cx, cy, 7), py = cy + hash01(cx, cy, 8);
    float d = sqrt(sq(x - px) + sq(y - py));
    if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d;
  }
  return 1 - sstep(0.0, 0.07, f2 - f1);
}

float bil(float a, float b, float c, float d, float fu, float fv) {
  return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv;
}

int argb(float a, float r, float g, float b) {
  return (constrain(round(a * 255), 0, 255) << 24) | (constrain(round(r * 255), 0, 255) << 16)
       | (constrain(round(g * 255), 0, 255) << 8) | constrain(round(b * 255), 0, 255);
}

// ── Into the mural, sharp ─────────────────────────────────────
// The tile as it is set in the mural: resampled from the baked image straight onto the mural's
// own pixel grid (several samples per pixel), cut to the outline of its bed with soft edges.
// Drawn 1:1 it stays as sharp as the baked tile — no on-the-fly shrinking by the graphics card,
// no half-pixel blur. s = mural pixels per tile unit; at = where its top-left pixel goes.
PImage muralStamp(TrencadisTile t, PImage src, float s, int[] at) {
  src.loadPixels();
  int sw = src.width, sh = src.height;
  float k = sw / t.bakeW;                                  // baked pixels per tile unit
  float ox = t.origin.x, oy = t.origin.y;
  float bx0 = Float.MAX_VALUE, by0 = Float.MAX_VALUE, bx1 = -Float.MAX_VALUE, by1 = -Float.MAX_VALUE;
  for (int i = 0; i < t.gx.length; i++) { bx0 = min(bx0, t.gx[i]); bx1 = max(bx1, t.gx[i]); by0 = min(by0, t.gy[i]); by1 = max(by1, t.gy[i]); }
  int px0 = floor((bx0 + ox) * s) - 1, py0 = floor((by0 + oy) * s) - 1;
  int w = ceil((bx1 + ox) * s) + 1 - px0, h = ceil((by1 + oy) * s) + 1 - py0;
  at[0] = px0; at[1] = py0;
  int ss = constrain(round(k / s) + 1, 2, 4);             // samples per pixel side: enough to cover the baked pixels it spans
  int[] out = new int[w * h];
  int n = t.gx.length;
  for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) {
    float r = 0, g = 0, b = 0; int cov = 0;
    for (int sy = 0; sy < ss; sy++) for (int sx = 0; sx < ss; sx++) {
      float X = (px0 + i + (sx + 0.5) / ss) / s - ox, Y = (py0 + j + (sy + 0.5) / ss) / s - oy;
      boolean in = false;
      for (int e = 0, f = n - 1; e < n; f = e, e++)
        if (((t.gy[e] > Y) != (t.gy[f] > Y)) && (X < (t.gx[f] - t.gx[e]) * (Y - t.gy[e]) / (t.gy[f] - t.gy[e]) + t.gx[e])) in = !in;
      if (!in) continue;
      cov++;
      float u = (X - t.bakeX0) * k - 0.5, v = (Y - t.bakeY0) * k - 0.5;
      int x0 = constrain((int) Math.floor(u), 0, sw - 1), y0 = constrain((int) Math.floor(v), 0, sh - 1);
      int x1 = min(sw - 1, x0 + 1), y1 = min(sh - 1, y0 + 1);
      float fu = constrain(u - x0, 0, 1), fv = constrain(v - y0, 0, 1);
      int c00 = src.pixels[y0 * sw + x0], c10 = src.pixels[y0 * sw + x1], c01 = src.pixels[y1 * sw + x0], c11 = src.pixels[y1 * sw + x1];
      r += bil((c00 >> 16) & 255, (c10 >> 16) & 255, (c01 >> 16) & 255, (c11 >> 16) & 255, fu, fv);
      g += bil((c00 >> 8) & 255, (c10 >> 8) & 255, (c01 >> 8) & 255, (c11 >> 8) & 255, fu, fv);
      b += bil(c00 & 255, c10 & 255, c01 & 255, c11 & 255, fu, fv);
    }
    if (cov == 0) continue;
    out[j * w + i] = argb(cov / (float) (ss * ss), r / cov / 255, g / cov / 255, b / cov / 255);
  }
  PImage img = createImage(w, h, ARGB);
  img.loadPixels();
  System.arraycopy(out, 0, img.pixels, 0, out.length);
  img.updatePixels();
  return img;
}
