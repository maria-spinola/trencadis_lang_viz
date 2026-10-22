// ═══════════════════════════════════════════════════════════
// Backdrop.pde
// What is behind the mural, instead of black (BACKDROP in Config.pde):
//   "black" — nothing
//   "stone" — the walls and the floor of natural stone (data/stone_*.jpg), lit by a low light going round the room
//   "glow"  — a smoke of the trencadís' colours behind the walls (and coming onto the floor), at three
//             depths, turning slowly round the room and curling: depth behind the mural, never competing with it.
// ═══════════════════════════════════════════════════════════

boolean glowOn() { return backdropMode() >= 0; }   // a backdrop drawn by data/smoke.glsl
int backdropMode() {
  if (BACKDROP.equalsIgnoreCase("glow")) return 0;
  if (BACKDROP.equalsIgnoreCase("stone"))   return 2;
  return -1;
}
boolean backdropOn() { return glowOn(); }

// The smoke (data/smoke.glsl): one field round the whole room, walls and floor, behind them at three
// depths, seen from the audience; it turns slowly round the room and curls, taking the trencadís'
// colours and mixing them. It is soft, so it is computed at BACKDROP_RES of each surface's resolution
// (before the surfaces are drawn) and enlarged onto it.
PShader smokeShader;
PGraphics[] smokeBufs = new PGraphics[5];
PGraphics[] stoneNormals = new PGraphics[5];   // "stone": its relief, for the light that moves (smokeBufs hold its colour)
PShader stoneLight;
PGraphics smokeDummy;
PImage[] stonePhotos;
boolean stoneHasPhotos = false;

void updateBackdrop() {
  if (!glowOn()) return;
  if (smokeShader == null) {
    smokeShader = loadShader("smoke.glsl");
    smokeDummy = createGraphics(4, 4, P2D);
    smokeDummy.beginDraw(); smokeDummy.background(0); smokeDummy.endDraw();
  }
  PShader sh = smokeShader;
  PVector E = viewerEye();
  float[] P = new float[24];
  int n = min(8, BACKDROP_COLORS.length);
  for (int i = 0; i < n; i++) { float[] c = rgb01(BACKDROP_COLORS[i]); P[i * 3] = c[0]; P[i * 3 + 1] = c[1]; P[i * 3 + 2] = c[2]; }
  sh.set("uPal", P, 3);
  sh.set("uNPal", (float) n);
  sh.set("uEye", E.x, E.y, E.z);
  sh.set("uCentre", ROOM_W / 2, ROOM_D / 2);
  sh.set("uRoom", ROOM_W, ROOM_D);
  sh.set("uReach", min(ROOM_W, ROOM_D) * BACKDROP_FLOOR_REACH);
  sh.set("uTime", frameCount / 60.0);
  sh.set("uDrift", 0.004 * BACKDROP_DRIFT);
  sh.set("uWallH", WALL_H);
  sh.set("uScale", BACKDROP_SCALE);
  sh.set("uDensity", BACKDROP_DENSITY);
  sh.set("uSoft", BACKDROP_SOFTNESS);
  sh.set("uSat", BACKDROP_SATURATION);
  sh.set("uHaze", BACKDROP_HAZE);
  sh.set("uFlipY", 1.0);
  int mode = backdropMode();
  sh.set("uMode", (float) mode);
  float[] SC = new float[12];
  for (int i = 0; i < 4; i++) { float[] c = rgb01(STONE_COLORS[i % STONE_COLORS.length]); SC[i * 3] = c[0]; SC[i * 3 + 1] = c[1]; SC[i * 3 + 2] = c[2]; }
  sh.set("uStone", SC, 3);
  if (mode == 2 && stonePhotos == null) {   // photographs of stone (data/stone_rock, stone_grain, stone_slate .jpg)
    String[] nm = { "stone_rock.jpg", "stone_grain.jpg", "stone_slate.jpg" };
    stonePhotos = new PImage[3];
    boolean all = true;
    for (int i = 0; i < 3; i++) { File fi = new File(dataPath(nm[i])); stonePhotos[i] = fi.exists() ? loadImage(nm[i]) : null; all &= stonePhotos[i] != null; }
    stoneHasPhotos = all;
    println("Stone backdrop: " + (all ? "from the photographs in data/" : "generated (no photographs)"));
  }
  if (mode == 2) {
    sh.set("uHasPhotos", stoneHasPhotos ? 1.0 : 0.0);
    sh.set("uRough", STONE_ROUGHNESS);
    if (stoneHasPhotos) { sh.set("uRock", stonePhotos[0]); sh.set("uGrain", stonePhotos[1]); sh.set("uSlate", stonePhotos[2]); }
  }
  float lvl = mode == 2 ? STONE_LEVEL : BACKDROP_LEVEL;
  for (Face f : faces) {
    boolean fl = f.id == FLOOR;
    if (fl && (!HAS_FLOOR || (mode == 2 ? STONE_FLOOR : BACKDROP_FLOOR) <= 0)) continue;
    if (smokeBufs[f.id] != null && (frameCount + f.id) % 2 != 0) continue;   // it moves slowly: each surface every other frame
    if (mode == 2 && smokeBufs[f.id] != null && frameCount > 10) continue;   // the stone is still: drawn once
    if (smokeBufs[f.id] == null) smokeBufs[f.id] = layerGraphics(max(16, round(f.pg.width * BACKDROP_RES * (mode == 2 ? 10 : 1))), max(16, round(f.pg.height * BACKDROP_RES * (mode == 2 ? 10 : 1))));   // (the stone: fine detail, drawn once)
    sh.set("uFace", f.w, f.h);
    sh.set("uOrg", f.O.x, f.O.y, f.O.z);
    sh.set("uAxU", f.eU.x, f.eU.y, f.eU.z);
    sh.set("uAxV", f.eV.x, f.eV.y, f.eV.z);
    sh.set("uIsFloor", fl ? 1.0 : 0.0);
    sh.set("uLevel", lvl * (fl ? (mode == 2 ? STONE_FLOOR : BACKDROP_FLOOR) : 1));
    sh.set("uOut", mode == 2 ? 1.0 : 0.0);   // the stone: its colour here, its relief below (lit each frame)
    PGraphics b = smokeBufs[f.id];
    b.beginDraw();
    b.shader(sh);
    b.image(smokeDummy, 0, 0, b.width, b.height);
    b.resetShader();
    b.endDraw();
    if (mode == 2) {
      if (stoneNormals[f.id] == null) stoneNormals[f.id] = layerGraphics(b.width, b.height);
      sh.set("uOut", 2.0);
      PGraphics nb = stoneNormals[f.id];
      nb.beginDraw();
      nb.shader(sh);
      nb.image(smokeDummy, 0, 0, nb.width, nb.height);
      nb.resetShader();
      nb.endDraw();
    }
  }
}

// "stone": the light going slowly round the room, low (raking: the relief stands out where it falls)
// (the room dims a little while a moment of the walls comes, like the mural: WallMoments.pde)
void drawStone(PGraphics pg, Face f) {
  PShader sh = stoneLightShader();
  stoneUniforms(sh, f, 1 - 0.4 * fxDim, 1);
  pg.shader(sh);
  pg.image(smokeBufs[f.id], 0, 0, f.w, f.h);
  pg.resetShader();
}
boolean stoneFloor() { return backdropMode() == 2 && HAS_FLOOR && STONE_FLOOR > 0 && smokeBufs[FLOOR] != null && stoneNormals[FLOOR] != null; }

void drawBackdrop(PGraphics pg, Face f) {
  if (f.id == FLOOR) {   // the floor is black (its reflection, FloorEcho.pde) — but on stone, it is stone too, a little darker
    if (stoneFloor()) drawStone(pg, f);
    return;
  }
  if (!glowOn() || smokeBufs[f.id] == null) return;
  if (backdropMode() == 2 && stoneNormals[f.id] != null) drawStoneWall(pg, f);   // StoneMoments.pde: a slab when the wall falls
  else pg.image(smokeBufs[f.id], 0, 0, f.w, f.h);
  if (f.id == MAIN_FACE && BACKDROP_TEXT_SHADE > 0) {   // the word and the text box stay readable
    pg.imageMode(CENTER);
    pg.tint(0, 0, 0, 100 * BACKDROP_TEXT_SHADE);
    pg.image(shadeSprite(), f.w / 2, (holdTopY() + msgTopY()) / 2 + f.h * 0.1, f.w * 0.95, f.h * 1.7);
    pg.noTint();
    pg.imageMode(CORNER);
  }
}

// On the floor (after its reflection, FloorEcho.pde): the same smoke, coming from the walls
void drawBackdropFloor(PGraphics pg, Face f) {
  if (!glowOn() || f.id != FLOOR || smokeBufs[FLOOR] == null || backdropMode() == 2) return;   // (the stone floor is drawn under the reflection)
  pg.blendMode(ADD);
  pg.image(smokeBufs[FLOOR], 0, 0, f.w, f.h);
  pg.blendMode(BLEND);
}

// a soft round sprite (the shade behind the text)
PImage shadeImg;
PImage shadeSprite() {
  if (shadeImg != null) return shadeImg;
  PGraphics g = createGraphics(128, 128, JAVA2D);
  g.beginDraw();
  g.loadPixels();
  for (int y = 0; y < 128; y++) for (int x = 0; x < 128; x++) {
    float dd = dist(x, y, 63.5, 63.5) / 63.5, a = constrain(pow(max(0, 1 - dd), 2.2), 0, 1);
    g.pixels[y * 128 + x] = (round(255 * a) << 24) | 0xFFFFFF;   // white (explicit: the sketch draws in HSB)
  }
  g.updatePixels();
  g.endDraw();
  shadeImg = g.get();
  return shadeImg;
}
