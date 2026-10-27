// ═══════════════════════════════════════════════════════════
// StoneMoments.pde
// With BACKDROP "stone" the stone is the wall itself (data/smoke.glsl), and it takes part in the
// moments of the walls (WallMoments.pde): in "tilt" the walls fall over the audience as solid slabs of
// stone with their trencadís on them. Also here: the shadows on the floor of what is out in the room,
// and reading the moving pictures smoothly.
// ═══════════════════════════════════════════════════════════

final float STONE_DEPTH = 120;        // how thick the stone wall is (the edges of a slab)
PShader stoneLightShader() { if (stoneLight == null) stoneLight = loadShader("stonelight.glsl"); return stoneLight; }

boolean stoneMode() { return backdropMode() == 2 && stoneNormals[W1] != null; }

// An image drawn moving, turned or scaled (a tile in the air, a slab of stone) must be read smoothly: the
// layers are made without smoothing (Room.pde: layerGraphics), and read point by point a fine pattern
// sliding by a fraction of a pixel glitters. Switched while a moment plays — before the walls are drawn,
// never in the middle of drawing one (asking another image for its texture there broke the drawing:
// the tiles were drawn out of place). At rest, 1:1, the mural looks exactly the same either way.
ArrayList<processing.opengl.Texture> smoothList = new ArrayList<processing.opengl.Texture>();
IntList smoothWas = new IntList();
void fxSmooth(boolean on) {
  if (!on) {
    for (int i = 0; i < smoothList.size(); i++) smoothList.get(i).usingMipmaps(false, smoothWas.get(i));
    smoothList.clear(); smoothWas.clear();
    return;
  }
  if (smoothList.size() > 0) return;
  ArrayList<PImage> all = new ArrayList<PImage>();
  all.add(matrixOut);                            // (the preview shows the matrix much smaller: read smoothly, it doesn't shimmer)
  for (PGraphics o : outImgs) all.add(o);
  for (PGraphics[] arr : new PGraphics[][] { mosaicLayers, glossLayers, cenefaLayers, cenefaGloss, smokeBufs, stoneNormals })
    for (PGraphics g : arr) if (g != null) { all.add(g); if (softOf(g) != null) all.add(softOf(g)); }
  for (PImage g : all) {
    if (!(g instanceof PGraphicsOpenGL)) continue;
    processing.opengl.Texture t = ((PGraphicsOpenGL) g).getTexture();
    if (t == null || smoothList.contains(t)) continue;
    // how it was read: point by point (2), smooth when shrunk only (3), or smooth (4)
    int was = t.glMagFilter == PGL.NEAREST ? (t.glMinFilter == PGL.NEAREST ? 2 : 3) : 4;
    if (was == 4) continue;
    smoothList.add(t); smoothWas.append(was);
    t.usingMipmaps(false, 4);   // bilinear
  }
}

PVector stoneSun() {
  float az = stoneSunAz(), el = radians(STONE_LIGHT_HEIGHT);
  return new PVector(cos(az) * cos(el), sin(az) * cos(el), sin(el));
}
float stoneSunAz() { return radians(STONE_LIGHT_START) + (STONE_LIGHT_PERIOD > 0 ? TWO_PI * (millis() / 1000.0) / STONE_LIGHT_PERIOD : 0); }

// The stone of a wall (Backdrop.pde): as a slab when the wall is falling (tilt), else as it is
void drawStoneWall(PGraphics pg, Face f) {
  if (fxSlab(f.id)) drawSlabs(pg, f);   // (a neighbour leaning over this wall is drawn over its mural: WallMoments.pde)
  else drawStone(pg, f);
}

float[] stoneAvg() {
  float[] a = rgb01(STONE_COLORS[0]), b = rgb01(STONE_COLORS[min(1, STONE_COLORS.length - 1)]);
  float k = STONE_LEVEL * 0.78;
  return new float[] { (a[0] + b[0]) / 2 * k, (a[1] + b[1]) / 2 * k, (a[2] + b[2]) / 2 * k };
}
void fillRGB(PGraphics pg, float[] c, float k) { fillRGB(pg, c, k, 1); }
void fillRGB(PGraphics pg, float[] c, float k, float a) {
  pg.fill((round(constrain(a, 0, 1) * 255) << 24) | (round(constrain(c[0] * k, 0, 1) * 255) << 16) | (round(constrain(c[1] * k, 0, 1) * 255) << 8) | round(constrain(c[2] * k, 0, 1) * 255));
}

void stoneUniforms(PShader sh, Face f, float k, float alpha) {
  float az = stoneSunAz(), el = radians(STONE_LIGHT_HEIGHT);
  sh.set("uSun", cos(az) * cos(el), sin(az) * cos(el), sin(el));
  sh.set("uSunK", STONE_LIGHT);
  sh.set("uLevel", STONE_LEVEL * k);
  boolean fl = f.id == FLOOR;   // the floor: darker in the middle, as the walls at its edges (no seam)
  sh.set("uFloor", fl ? 1.0 : 0.0, fl ? STONE_FLOOR : 1, fl ? STONE_FLOOR_EDGE : 1, STONE_FLOOR_FADE);
  sh.set("uFloorMural", STONE_FLOOR_EDGE_MURAL, STONE_FLOOR_WOBBLE);
  sh.set("uFloorSize", f.w, f.h);
  sh.set("uNormal", stoneNormals[f.id]);
  sh.set("uAlpha", alpha);
}

// shadows on the floor of the tiles out in the room (in the room's camera, before what is on it)
void drawFloorShadows(PGraphics pg, Face f) {
  if (f.id != FLOOR || fxType < 0) return;
  // the light of the room from high above (a raking sun would draw long streaks from everything that moves)
  PVector L = new PVector(-0.18, -0.12, 1);
  float lz = 1;
  pg.noStroke();
  for (FxTile ft : fxTiles) {   // only what is out in the room (not a tile still on its wall)
    if (!ft.moved || ft.C.z > WALL_H * 0.75 || !reachesFace(ft.C, faces[ft.face], ft.rad * 3, f)) continue;
    float out = PVector.sub(ft.C, faces[ft.face].toRoom(0, 0)).dot(faces[ft.face].n);
    float k = smooth01((out - 60) / 200.0);
    if (k < 0.01) continue;
    int n = ft.xs.length;
    float[][] q = new float[n][2];
    for (int i = 0; i < n; i++) { float z = max(0, ft.vz[i]); q[i][0] = ft.vx[i] - L.x * z; q[i][1] = ft.vy[i] - L.y * z; }
    float a = 0.32 * k * (1 - smooth01(ft.C.z / (WALL_H * 0.75))) * ft.alpha;
    shadowPoly(pg, hull2(q), a);
  }
}

void shadowPoly(PGraphics pg, float[][] h, float a) {
  if (h.length < 3 || a < 0.004) return;
  float cx = 0, cy = 0;
  for (float[] p : h) { cx += p[0] / h.length; cy += p[1] / h.length; }
  for (int ring = 1; ring >= 0; ring--) {   // a soft edge round a darker middle
    float s = 1 + ring * 0.08;
    pg.fill(0, 0, 0, 100 * a * (ring == 0 ? 0.7 : 0.35));
    pg.beginShape();
    for (float[] p : h) pg.vertex(cx + (p[0] - cx) * s, cy + (p[1] - cy) * s, 0.4);
    pg.endShape(CLOSE);
  }
}

// convex hull of 2D points (gift wrapping: few points)
float[][] hull2(float[][] p) {
  int n = p.length;
  if (n < 3) return p;
  int l = 0;
  for (int i = 1; i < n; i++) if (p[i][0] < p[l][0]) l = i;
  ArrayList<float[]> h = new ArrayList<float[]>();
  int a = l;
  do {
    h.add(p[a]);
    int b = (a + 1) % n;
    for (int i = 0; i < n; i++) {
      float cr = (p[b][0] - p[a][0]) * (p[i][1] - p[a][1]) - (p[b][1] - p[a][1]) * (p[i][0] - p[a][0]);
      if (cr < 0) b = i;
    }
    a = b;
  } while (a != l && h.size() <= n);
  return h.toArray(new float[0][]);
}

// Does something at C (out of the wall `home`) show on surface g? Seen from the audience, it falls on
// g's plane within reach of it (the opposite wall never)
boolean reachesFace(PVector C, Face home, float m, Face g) {
  if (g.id == FLOOR && !HAS_FLOOR) return false;
  if (home.id == g.id) return true;
  if (g.id != FLOOR && home.n.dot(g.n) < -0.5) return false;
  PVector E = viewerEye(), D = PVector.sub(C, E);
  float den = D.dot(g.n);
  if (abs(den) < 1e-4) return false;
  float k = PVector.sub(g.O, E).dot(g.n) / den;
  if (k <= 0) return false;
  PVector P = PVector.add(E, PVector.mult(D, k)), r = PVector.sub(P, g.O);
  float u = r.dot(g.eU), v = r.dot(g.eV);
  m += 220;   // (a little generous: what is outside is clipped anyway — a tight margin made pieces near a corner blink)
  return u > -m && u < g.w + m && v > -m && v < g.h + m;
}

// ── tilt: whole walls as slabs of stone ─────────────────────

// a wall that moves as one, now (only on stone: on the other backdrops its tiles move by themselves)
// (once a wall has started moving it stays a slab until it has been still a while: a wall bouncing through
// its place would otherwise flick between the slab and the painted wall for a frame)
int[] slabStill = new int[5];
boolean[] slabOn = new boolean[5];
void updateSlabs() {
  for (int w = 1; w <= 4; w++) {
    boolean moving = stoneMode() && fxType == FX_TILT && abs(fxWallTilt[w]) > 1e-4;
    slabStill[w] = moving ? 0 : slabStill[w] + 1;
    slabOn[w] = stoneMode() && fxType >= 0 && (moving || (slabOn[w] && slabStill[w] < 12));
  }
}
boolean fxSlab(int face) { return face != FLOOR && slabOn[face]; }
// a neighbouring wall leaning into f (over its corner, or over the floor)
boolean slabReaches(Face f) {
  for (int w = 1; w <= 4; w++) if (slabOver(w, f)) return true;
  return false;
}
boolean slabOver(int w, Face f) { return w != f.id && fxSlab(w) && abs(fxWallTilt[w]) > 1e-4 && (f.id == FLOOR || faces[w].n.dot(f.n) > -0.5); }

// a point of wall `face` at (u, v), w towards the room, where the moving wall has taken it
PVector slabPoint(int face, float u, float v, float w) {
  Face f = faces[face];
  float th = fxWallTilt[face];
  if (th != 0) {   // leaning about its foot (v = WALL_H, w = 0): its top comes into the room
    float c = cos(th), s = sin(th), H = WALL_H;
    float v2 = H + (v - H) * c + w * s, w2 = -(v - H) * s + w * c;
    v = v2; w = w2;
  }
  return new PVector(f.O.x + f.eU.x * u + f.eV.x * v + f.n.x * w, f.O.y + f.eU.y * u + f.eV.y * v + f.n.y * w, f.O.z + f.eU.z * u + f.eV.z * v + f.n.z * w);
}

// the moving walls seen on surface f (its own, and its neighbours' where they come into it), solid:
// their stone face and the edges of the slab, in depth order
void drawSlabs(PGraphics pg, Face f) {
  viewerCamera(pg, f);
  pg.hint(ENABLE_DEPTH_TEST);
  pg.noStroke();
  pg.textureMode(NORMAL);
  PShader sh = stoneLightShader();
  float[] sc = stoneAvg();
  for (int w = 1; w <= 4; w++) {
    if (!(w == f.id && fxSlab(w)) && !slabOver(w, f)) continue;
    Face F = faces[w];
    PVector a = slabPoint(w, 0, 0, 0), b = slabPoint(w, F.w, 0, 0), c = slabPoint(w, F.w, F.h, 0), d = slabPoint(w, 0, F.h, 0);
    // the slab's thickness: its edges (top, bottom, the two ends), behind its face
    PVector[] fr = { a, b, c, d };
    PVector[] bk = { slabPoint(w, 0, 0, -STONE_DEPTH), slabPoint(w, F.w, 0, -STONE_DEPTH), slabPoint(w, F.w, F.h, -STONE_DEPTH), slabPoint(w, 0, F.h, -STONE_DEPTH) };
    float tilt = fxWallTilt[w];
    for (int i = 0; i < 4; i++) {
      int j = (i + 1) % 4;
      float lit = i == 0 ? 0.75 + 0.2 * sin(tilt) : 0.42;   // the top edge catches the light
      pg.beginShape(QUADS);
      fillRGB(pg, sc, lit * (1 - 0.4 * fxDim));
      pg.vertex(fr[i].x, fr[i].y, fr[i].z); pg.vertex(fr[j].x, fr[j].y, fr[j].z);
      fillRGB(pg, sc, lit * 0.7 * (1 - 0.4 * fxDim));
      pg.vertex(bk[j].x, bk[j].y, bk[j].z); pg.vertex(bk[i].x, bk[i].y, bk[i].z);
      pg.endShape();
    }
    // its stone face, lit as it leans (towards the light above: brighter)
    float lean = 1 + 0.35 * sin(tilt);
    stoneUniforms(sh, F, lean * (1 - 0.4 * fxDim), 1);
    pg.shader(sh);
    pg.beginShape(QUADS);
    pg.texture(smokeBufs[w]);
    pg.vertex(a.x, a.y, a.z, 0, 0); pg.vertex(b.x, b.y, b.z, 1, 0); pg.vertex(c.x, c.y, c.z, 1, 1); pg.vertex(d.x, d.y, d.z, 0, 1);
    pg.endShape();
    pg.resetShader();
  }
  pg.hint(DISABLE_DEPTH_TEST);
  flatCamera(pg, f);
}
