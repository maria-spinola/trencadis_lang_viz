// ═══════════════════════════════════════════════════════════
// WallMoments.pde
// Now and then the walls stop being solid. With nobody writing, every WALL_MOMENTS_EVERY_MIN…MAX
// seconds the room plays a "moment": the mural's own tiles leave the wall in 3D, seen from the
// audience (the camera rig at eye height, Room.pde: viewerCamera), with the body they have on the wall
// (MURAL_THICK: glazed sides in their own colour, an unglazed back), their shadow on the wall and the bed
// of mortar they leave behind — and they always come back. Nothing vanishes: what falls lies on the floor.
//   wave       a wave of tiles coming out in relief runs right round the room
//   tilt       the walls fall over the audience — the far wall, then the two side walls (never two that
//              meet at a corner at once: they would go through each other) — are caught, and pushed back
//   heartbeat  swells rise out of the mural at different places, one after another, like drops in water
//   swap       pairs of tiles fly across the room and change places for good: each one, turning over in
//              the air, takes the shape of the other's place and settles in it (Mosaic.pde: re-made there)
//   collapse   the border falls apart piece by piece onto the floor (at the foot of the walls if there is
//              no floor) and, after a silence, flies back up into its place the long way round
// On the "stone" backdrop the stone is the wall: tilt moves it as one slab with the trencadís on it
// (StoneMoments.pde); a tile that leaves shows the stone under its bed of mortar.
// Each one is announced: the light dims a little (WALL_MOMENTS_CUE).
// A visitor's key, or a word on its way, sends everything gently home at once.
// Only the tiles that move are drawn (textured polygons over the wall's own layer, lit by the mural's
// shader), so the cost is small. Ctrl+W plays the next one now. Settings: WALL_MOMENTS_* in Config.pde.
// Inspiration: Urbanscreen's 555 KUBIK, the Casa Batlló mappings, NuFormer / AntiVJ façades —
// architecture that behaves as if it weren't solid, always with real shadows and real gaps.
// ═══════════════════════════════════════════════════════════

final String[] FX_NAMES = { "wave", "", "tilt", "heartbeat", "swap", "", "collapse" };   // ("" : rise and piano, removed)
final int COLLAPSE_BACK = 420;   // collapse: frames until the border flies back up (SoundEngine.pde plays it then)
final int FX_WAVE = 0, FX_TILT = 2, FX_HEART = 3, FX_SWAP = 4, FX_COLLAPSE = 6;

class FxTile {
  int face, band;
  float[] xs, ys;              // outline on its wall (wall units)
  float cx, cy, rad, ringX;
  boolean cen;                 // a cell of the border (Cenefa.pde) rather than a tile of the mural
  PGraphics col, rel;          // its layer and relief layer
  float layerH;                // the layer's height (wall units)
  PVector home;                // its glazed face's centre at rest (room): MURAL_THICK proud of the wall
  PVector[] homeP;             // its outline at rest, on the wall (room)
  float a, b, delay, delay2;   // its own random values for the moment
  FxTile partner;              // swap
  JSONObject rec;              // its record in the mural (Mosaic.pde)
  FxTile dest;                 // swap: its shape in the other's place, where it is re-made
  boolean switched, force;     // swap: it has taken that shape · drawn out of the wall even at rest
  PVector fromHome, toHome;    // swap: where it leaves from, where it goes (its face's centre at rest)
  int fromFace, toFace;
  int src;                     // the wall whose layer its picture comes from
  JSONObject remadeRec;        // swap: its word in the other's place…
  TrencadisTile remade;        // …made beforehand, away from the drawing (it takes a moment)
  int remadeN;
  // collapse: where it falls to (planned when the moment starts)
  PVector landC;
  float[] turn;                // the turn from the wall to lying there (axis x, y, z, angle)
  float T1;                    // frames of its fall
  // pose this frame
  PVector C = new PVector(), bx = new PVector(), by = new PVector(), bz = new PVector();
  float lift, alpha = 1, disp, sheen;
  int still;                   // frames it has been at rest
  boolean column = true, moved;
  float[] vx, vy, vz;          // its outline this frame (room)
}

ArrayList<FxTile> fxTiles = new ArrayList<FxTile>();
int fxType = -1, fxStart, fxDur, fxAbortAt = -1, fxNextAt = 0, fxLast = -1, fxLast2 = -1, fxQueued = -1;
float fxDim = 0;               // the room dims while a moment comes (Mural.pde)
float[] fxWallTilt = new float[5];

boolean fxActive() { return fxType >= 0; }
float fxT() { return max(4, MURAL_THICK); }   // the body of a tile: as thick as on the wall (Mural.pde)

// ── Scheduling ──────────────────────────────────────────────

void updateWallMoments() {
  // the copies swap needs are made now, at start: making an OpenGL image in the middle of the show can
  // flash the screen black for a frame (the first swap of the night did)
  if (frameCount == 3) for (int w = 1; w <= 4; w++) {
    if (mosaicLayers[w] != null && swapOld[w] == null) swapOld[w] = copyLayer(null, mosaicLayers[w]);
    if (glossLayers[w] != null && swapOldGloss[w] == null) swapOldGloss[w] = copyLayer(null, glossLayers[w]);
  }
  // the layers are read smoothly (no glitter as tiles move), set once here at start — changing it as each
  // moment began flashed the screen black for a frame (StoneMoments.pde: fxSmooth)
  if (frameCount == 15) fxSmooth(true);
  if (fxNextAt == 0) fxNextAt = frameCount + round(random(WALL_MOMENTS_EVERY_MIN, WALL_MOMENTS_EVERY_MAX) * 60);
  boolean running = fxType >= 0 && fxAbortAt < 0;
  fxDim = lerp(fxDim, running && frameCount - fxStart < WALL_MOMENTS_CUE + fxDur - 90 ? WALL_MOMENTS_DIM : 0, 0.035);
  if (fxType < 0) {
    if (fxQueued >= 0 && roomCalm(0)) { startWallMoment(fxQueued); fxQueued = -1; return; }
    if (fxLandPending) { landMoment(); return; }   // a word has just settled: the room answers it
    if (!WALL_MOMENTS || frameCount < fxNextAt) return;
    if (roomCalm(5000)) startWallMoment(nextWallMoment());
    else fxNextAt = frameCount + 60 * 5;   // not now: try again in a while
    return;
  }
  // the words wait for the moment to end (wordBusy); only a tile already flying sends everything home
  if (fxAbortAt < 0 && flightsBusy()) fxAbortAt = frameCount;
  int t = frameCount - fxStart - WALL_MOMENTS_CUE;
  if (fxType == FX_WAVE) waveSounds(t);
  if (fxAbortAt >= 0 && fxAbortT < 0) fxAbortT = t;
  if (fxType == FX_SWAP && fxSwapDone && fxAbortAt >= 0)   // the tiles have already changed places: they finish, quickly
    t = round(fxAbortT + (frameCount - fxAbortAt) * max(1, (fxDur - fxAbortT) / 48.0));
  if ((fxAbortAt >= 0 && frameCount - fxAbortAt > 50) || t > fxDur) { endWallMoment(); return; }
  if (fxType == FX_SWAP && t >= 0 && !fxSwapDone) swapInMural();
  else if (fxType == FX_SWAP) swapNextPair();
  for (int w = 0; w < 5; w++) fxWallTilt[w] = 0;
  if (fxType == FX_TILT) poseTilt(t);
  if (fxAbortAt >= 0) {   // a visitor: the walls go back too, the tiles riding on them
    float k = 1 - smooth01((frameCount - fxAbortAt) / 50.0);
    for (int w = 0; w < 5; w++) fxWallTilt[w] *= k;
  }
  updateSlabs();   // StoneMoments.pde
  for (FxTile ft : fxTiles) poseTile(ft, t);
}

// A word has settled: a moment answers it once every word on its way has landed (no new word leaves the
// main wall meanwhile: wordBusy, ClaudeSketch.pde); the next words wait for it to end
void landMoment() {
  if (!WALL_MOMENTS || millis() - fxEndMs < WALL_MOMENTS_LAND_GAP * 1000) { fxLandPending = false; return; }   // one has just played: not now
  if (flightsBusy() || isLoading || frameCount - fxLandAt < 50) return;   // (the others first; a breath after it lands)
  fxLandPending = false;
  startWallMoment(nextWallMoment());
}

boolean flightsBusy() {
  for (TileFlight fl : flights) if (!fl.landed) return true;
  return false;
}

// nobody writing, nothing on its way, and no key for msQuiet
boolean roomCalm(int msQuiet) {
  return !isLoading && inputText.length() == 0 && wordQueue.size() == 0 && revealAlpha() < 0.01 && !flightsBusy() && autoWord == null
      && millis() - lastInteraction > msQuiet && mosaicLayers[W1] != null;
}

// ── Which moment: an answer to the last word ────────────────
// The room answers the last word that settled in the mural (a visitor's or one of the poem's): its
// emotion picks the moment — anger or surprise: the walls fall over the audience (tilt); fear, disgust or
// sadness: the border falls (collapse); love: the mural swells (heartbeat); joy: a wave; a rare or very
// Catalan word: tiles change places (swap) — and it starts where that word's tile is. The big ones (tilt,
// collapse) at most once every WALL_MOMENTS_BIG_GAP seconds: else a gentle one of the same mood.
// Never the same twice in a row. With no new word since the last one: any of the gentle or (if their
// time has come) big ones, from anywhere.
JSONObject fxWord;              // the last word that settled
boolean fxWordFresh = false;    // …and no moment has answered it yet
PVector fxOrigin;               // where the moment starts: face, x, y (null = anywhere)
int fxBigAt = -999999;          // when the last big one played (ms)

int fxEndMs = -999999;           // when the last moment ended (ms)
boolean fxLandPending = false;  // a word has settled: a moment answers it as soon as nothing else is flying
int fxLandAt = 0;
int[] fxPlayedAt = new int[16]; // when each moment last played (ms): the ones not seen for a while come first

void wallMomentWord(JSONObject rec, int face, float x, float y) {
  if (rec == null) return;
  fxWord = rec; fxWordFresh = true;
  fxOrigin = new PVector(face, x, y);
  if (WALL_MOMENTS_ON_LAND && fxType < 0) { fxLandPending = true; fxLandAt = frameCount; }
}
boolean fxBig(int type) { return type == FX_TILT || type == FX_COLLAPSE; }
int momentForWord(JSONObject r) {
  if (r.getInt("raresa", 0) >= SPECIAL_MIN || r.getInt("culturalitat", 0) >= SPECIAL_MIN) return FX_SWAP;
  switch (r.getInt("emotion", 7)) {
    case 1: case 2:         return FX_TILT;       // Ira, Sorpresa
    case 3: case 5: case 6: return FX_COLLAPSE;   // Por, Fàstic, Tristesa
    case 4:                 return FX_HEART;      // Amor
    default:                return FX_WAVE;       // Alegria
  }
}
int gentleFor(int type) { return (type == FX_COLLAPSE || type == FX_WAVE) ? FX_HEART : FX_WAVE; }

int nextWallMoment() {
  IntList ok = new IntList();
  for (String s : WALL_MOMENTS_LIST) for (int i = 0; i < FX_NAMES.length; i++) if (FX_NAMES[i].equalsIgnoreCase(s.trim()) && i != fxLast && i != fxLast2 && fxPlayable(i)) ok.append(i);   // (neither of the last two)
  if (ok.size() == 0) for (String s : WALL_MOMENTS_LIST) for (int i = 0; i < FX_NAMES.length; i++) if (FX_NAMES[i].equalsIgnoreCase(s.trim()) && i != fxLast && fxPlayable(i)) ok.append(i);
  if (ok.size() == 0) return fxLast >= 0 ? fxLast : 0;
  boolean bigOk = millis() - fxBigAt > WALL_MOMENTS_BIG_GAP * 1000;
  // every moment gets a chance that grows the longer it hasn't played (so all of them come round, the
  // walls falling and the swaps too); the one answering the last word's mood, WALL_MOMENTS_MOOD times more
  int want = -1;
  if (fxWord != null && fxWordFresh) { want = momentForWord(fxWord); if (fxBig(want) && !bigOk) want = gentleFor(want); }
  else fxOrigin = null;   // (not an answer to a word: from anywhere)
  FloatList wt = new FloatList();
  float sum = 0;
  for (int i : ok) {
    float w = 0;
    if (bigOk || !fxBig(i)) {
      w = 1 + min(600, (millis() - fxPlayedAt[i]) / 1000.0) / 60.0;   // + 1 for every minute it hasn't played
      if (i == want) w *= WALL_MOMENTS_MOOD;
    }
    wt.append(w); sum += w;
  }
  if (sum <= 0) return ok.get((int) random(ok.size()));
  float x = random(sum);
  for (int k = 0; k < ok.size(); k++) { x -= wt.get(k); if (x <= 0) return ok.get(k); }
  return ok.get(ok.size() - 1);
}

// how far along the ring of walls from where the moment starts (0 … ring), and both ways (0 … ring/2)
float ringFrom(float ringX) {
  float ring = 2 * (ROOM_W + ROOM_D);
  float o = fxOrigin == null ? 0 : moteRingStart((int) fxOrigin.x) + fxOrigin.y;
  return ((ringX - o) % ring + ring) % ring;
}
float ringBoth(float ringX) { float d = ringFrom(ringX), ring = 2 * (ROOM_W + ROOM_D); return min(d, ring - d); }
// the tile nearest where the moment starts (or null)
FxTile nearestOrigin(ArrayList<FxTile> list) {
  if (fxOrigin == null) return null;
  FxTile best = null; float bd = 1e9;
  for (FxTile t : list) { if (t.face != (int) fxOrigin.x) continue; float d = dist(t.cx, t.cy, fxOrigin.y, fxOrigin.z); if (d < bd) { bd = d; best = t; } }
  return best;
}

boolean fxPlayable(int type) { return type >= 0 && type < FX_NAMES.length && FX_NAMES[type].length() > 0; }

// Ctrl+W: the next one now (in order through the list)
int fxManual = 0;
void playNextWallMoment() {
  if (WALL_MOMENTS_LIST.length == 0) return;
  String s = WALL_MOMENTS_LIST[fxManual++ % WALL_MOMENTS_LIST.length].trim();
  for (int i = 0; i < FX_NAMES.length; i++) if (FX_NAMES[i].equalsIgnoreCase(s)) {
    if (!fxPlayable(i)) { playNextWallMoment(); return; }
    if (fxType >= 0) endWallMoment();
    if (roomCalm(0)) startWallMoment(i); else fxQueued = i;
  }
}

void endWallMoment() {
  fxType = -1;
  fxAbortAt = -1;
  fxAbortT = -1;
  fxSwapDone = false;
  for (int w = 0; w < 5; w++) { slabOn[w] = false; slabStill[w] = 0; }
  fxTiles.clear();
  for (int w = 0; w < 5; w++) fxWallTilt[w] = 0;
  fxNextAt = frameCount + round(random(WALL_MOMENTS_EVERY_MIN, WALL_MOMENTS_EVERY_MAX) * 60);
  fxEndMs = millis();
}

// Hooks for the sound (SoundEngine.pde; the cue sound itself waits for the tiles to move: updateMomentSounds)
void wallMomentCue(String name) { println("Wall moment: " + name); }
void wallMomentHit(String name) { soundMomentHit(name); }

// ── Starting a moment: which tiles take part ────────────────

void startWallMoment(int type) {
  fxTiles.clear();
  fxLast2 = fxLast;
  fxType = type; fxLast = type; fxStart = frameCount; fxAbortAt = -1; fxAbortT = -1; fxSwapDone = false;
  fxWordFresh = false;
  fxLandPending = false;
  if (fxBig(type)) fxBigAt = millis();
  if (type >= 0 && type < fxPlayedAt.length) fxPlayedAt[type] = millis();
  ArrayList<FxTile> mural = fxMuralTiles(), border = fxBorderTiles();
  float ring = 2 * (ROOM_W + ROOM_D);
  switch (type) {
    case FX_WAVE:   // each tile comes away from the wall by itself — no pillar of wall under it
      fxTiles.addAll(mural); fxTiles.addAll(border);
      for (FxTile t : fxTiles) t.column = false;
      fxDur = 760; break;
    case FX_TILT:
      fxTiles.addAll(mural); fxTiles.addAll(border);
      for (FxTile t : fxTiles) t.column = false;
      fxDur = TILT_STAGE * (stoneMode() ? 2 : 3) + 20; break;
    case FX_HEART: {   // a few places of the mural, far apart, swell one after another
      if (mural.size() == 0) { fxType = -1; return; }
      ArrayList<FxTile> seeds = new ArrayList<FxTile>();
      java.util.Collections.shuffle(mural);
      FxTile o0 = nearestOrigin(mural);   // the first swell where the word's tile is
      if (o0 != null) { mural.remove(o0); mural.add(0, o0); }
      for (FxTile c : mural) {
        boolean apart = true;
        for (FxTile o : seeds) if (o.face == c.face && dist(o.cx, o.cy, c.cx, c.cy) < WALL_H * 1.3) apart = false;
        if (apart) seeds.add(c);
        if (seeds.size() >= 6) break;
      }
      float R = WALL_H * 0.55;
      fxSeeds.clear();
      for (int k = 0; k < seeds.size(); k++) fxSeeds.add(new float[] { seeds.get(k).face, seeds.get(k).cx, seeds.get(k).cy, k * HEART_GAP });
      for (FxTile t : mural) {
        int best = -1; float bd = R;
        for (int k = 0; k < seeds.size(); k++) { FxTile sd = seeds.get(k); float d = dist(t.cx, t.cy, sd.cx, sd.cy); if (sd.face == t.face && d < bd) { bd = d; best = k; } }
        if (best < 0) continue;
        FxTile sd = seeds.get(best);
        t.a = 1 - 0.65 * bd / R;
        t.b = (t.cx - sd.cx) / R; t.delay2 = (t.cy - sd.cy) / R;   // the way it leans: away from the middle
        t.delay = best * HEART_GAP + bd / R * 30;                   // the swell spreads out like a ring on water
        fxTiles.add(t);
      }
      fxDur = round((seeds.size() - 1) * HEART_GAP + 30 + 150); break;
    }
    case FX_SWAP: {   // pairs that fit each other's place (a whole cell for a whole cell, a half for a half…)
      java.util.Collections.shuffle(mural);
      FxTile o0 = nearestOrigin(mural);   // the word's own tile is the first to change places
      if (o0 != null) { mural.remove(o0); mural.add(0, o0); }
      int pairs = min(WALL_MOMENTS_SWAPS, mural.size() / 2);
      ArrayList<FxTile> pool = new ArrayList<FxTile>(mural);
      for (int k = 0; k < pairs && pool.size() > 1; k++) {
        FxTile A = pool.remove(0), B = null;
        for (FxTile c : pool) if (sizeKind(c.rec) == sizeKind(A.rec) && (c.face != A.face || dist(c.cx, c.cy, A.cx, A.cy) > WALL_H * 1.5)) { B = c; break; }
        if (B == null) continue;
        pool.remove(B);
        A.partner = B; B.partner = A;
        A.a = random(1) < 0.5 ? 1 : -1; B.a = -A.a;
        A.fromHome = A.home; A.fromFace = A.face; A.toHome = B.home; A.toFace = B.face;
        B.fromHome = B.home; B.fromFace = B.face; B.toHome = A.home; B.toFace = A.face;
        A.delay = B.delay = fxTiles.size() / 2 * 26;
        A.column = B.column = false;
        fxTiles.add(A); fxTiles.add(B);
      }
      fxDur = round(fxTiles.size() / 2 * 26 + SWAP_OUT + SWAP_FLY + SWAP_IN + 20);
      prepareSwapTiles();
      break;
    }
    case FX_COLLAPSE:
      for (FxTile t : border) fxTiles.add(t);
      for (FxTile t : mural) if (t.band == 0 && random(1) < 0.4) fxTiles.add(t);
      for (FxTile t : fxTiles) {
        t.delay = ringBoth(t.ringX) / (ring / 2) * 120 + random(16);           // from where the word is, both ways round the room…
        t.delay2 = (1 - ringBoth(t.ringX) / (ring / 2)) * 110 + random(14);   // …and back the other way
        t.a = random(-1, 1); t.b = random(-1, 1);
        t.column = false;
      }
      for (FxTile t : fxTiles) planFall(t);
      fxDur = 720; break;
  }
  if (fxTiles.size() == 0) { fxType = -1; return; }
  wallMomentCue(FX_NAMES[type]);
}

// Every tile of the mural, as it is now
ArrayList<FxTile> fxMuralTiles() {
  ArrayList<FxTile> out = new ArrayList<FxTile>();
  for (int i = 0; i < mosaicTiles.size(); i++) {
    JSONObject r = mosaicTiles.getJSONObject(i);
    if (!r.hasKey("slot") || r.getInt("cycle", 0) != mosaicCycle) continue;
    int slot = r.getInt("slot"), face = slotFaces.get(slot);
    if (mosaicLayers[face] == null) continue;
    ArrayList<PVector> o = partPatch(slot, r.getInt("part", PART_WHOLE), r.getInt("slot2", -1)).outline();
    float[] xs = new float[o.size()], ys = new float[o.size()];
    for (int k = 0; k < o.size(); k++) { xs[k] = o.get(k).x; ys[k] = o.get(k).y; }
    FxTile t = fxTile(face, xs, ys, mosaicLayers[face], glossLayers[face], faces[face].h, false, slotBands.get(slot));
    t.rec = r;
    out.add(t);
  }
  return out;
}

ArrayList<FxTile> fxBorderTiles() {
  ArrayList<FxTile> out = new ArrayList<FxTile>();
  if (!CENEFA) return out;
  for (float[][] c : cenefaCells) {
    int w = (int) c[0][0];
    if (cenefaLayers[w] == null) continue;
    out.add(fxTile(w, c[1], c[2], cenefaLayers[w], cenefaGloss[w], cenefaLayers[w].height / RENDER_SCALE, true, -1));
  }
  return out;
}

FxTile fxTile(int face, float[] xs, float[] ys, PGraphics col, PGraphics rel, float layerH, boolean cen, int band) {
  FxTile t = new FxTile();
  t.face = face; t.src = face; t.xs = xs; t.ys = ys; t.col = col; t.rel = rel; t.layerH = layerH; t.cen = cen; t.band = band;
  for (int k = 0; k < xs.length; k++) { t.cx += xs[k] / xs.length; t.cy += ys[k] / ys.length; }
  for (int k = 0; k < xs.length; k++) t.rad = max(t.rad, dist(xs[k], ys[k], t.cx, t.cy));
  t.ringX = moteRingStart(face) + t.cx;
  Face f = faces[face];
  t.home = PVector.add(f.toRoom(t.cx, t.cy), PVector.mult(f.n, fxT()));
  t.homeP = new PVector[xs.length];
  for (int k = 0; k < xs.length; k++) t.homeP[k] = f.toRoom(xs[k], ys[k]);
  t.vx = new float[xs.length]; t.vy = new float[xs.length]; t.vz = new float[xs.length];
  t.a = random(-1, 1); t.b = random(-1, 1);
  return t;
}

// ── Poses ───────────────────────────────────────────────────

float S() { return WALL_MOMENTS_SCALE; }
float easeOutBack(float x) { x = constrain(x, 0, 1); float c = 1.6; return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2); }
float easeInCubic01(float x) { x = constrain(x, 0, 1); return x * x * x; }
// up, stay, down with a little rebound into the wall: 0 … 1 … 0 (… −0.15 … 0)
float envelope(float t, float up, float hold, float down) {
  if (t <= 0) return 0;
  if (t < up) return easeOutBack(t / up);
  t -= up;
  if (t < hold) return 1;
  t -= hold;
  if (t < down) return 1 - easeInCubic01(t / down);
  t -= down;
  return -0.16 * sin(PI * min(1, t / 20)) * exp(-t / 28);
}

void poseTile(FxTile ft, int t) {
  float cue = t < 0 ? smooth01((t + WALL_MOMENTS_CUE) / (float) WALL_MOMENTS_CUE) : 0;
  float du = 0, dv = 0, d = 0, rx = 0, ry = 0, rz = 0;
  ft.alpha = 1;
  if (t < 0) {   // the announcement: the light dims (the tiles stay painted on the wall: a tremble of a few
    wallPose(ft, 0, 0, 0, 0, 0, 0);   // units only made them flick between the wall and the room)
  } else switch (fxType) {
    case FX_WAVE: {
      float ring = 2 * (ROOM_W + ROOM_D);
      float X = lerp(-1400, ring + 1400, t / (float) (fxDur - 40));
      float x = (ringFrom(ft.ringX) + (ft.cy - WALL_H / 2) * 0.7 - X) / 900;   // (from where the word is, round the room)
      float e = exp(-x * x);
      d = WALL_H * 0.09 * S() * e * (0.85 + 0.15 * ft.a);   // it comes away a little, tipping over the crest
      rx = -0.3 * x * e * S();
      rz = 0.025 * ft.a * e;
      wallPose(ft, 0, 0, d, rx, 0, rz);
      break;
    }
    case FX_TILT:   // riding on its wall as it falls: tiles never move on it (they would go through each other)
      wallPose(ft, 0, 0, 0, 0, 0, 0);
      break;
    case FX_HEART: {
      float s = swell(t - ft.delay);
      d = WALL_H * 0.13 * S() * ft.a * s;
      ry = 0.14 * ft.b * s; rx = -0.14 * ft.delay2 * s;
      wallPose(ft, 0, 0, d, rx, ry, 0);
      if (ft == fxTiles.get(0)) for (float[] sd : fxSeeds) if (t == round(sd[3]) + 2) fxImpact((int) sd[0], sd[1], sd[2]);
      break;
    }
    case FX_SWAP:
      poseSwap(ft, t - ft.delay);
      break;
    case FX_COLLAPSE: {   // it comes loose, falls, lands and lies there; later the film runs backwards
      float Tf = ft.T1 + 26;
      float back = constrain((t - COLLAPSE_BACK - ft.delay2) / 120.0, 0, 1);
      if (back > 0) poseReturn(ft, back);   // back up into its place, the long way round
      else {
        float tau = constrain(t - ft.delay, 0, Tf);
        if (tau <= 0) {
          float wob = (t - ft.delay > -24) ? sin(frameCount * 1.3 + ft.a * 9) * 0.04 : 0;   // loosening
          wallPose(ft, 0, 0, 0, 0, 0, wob);
        } else poseFall(ft, tau);
      }
      if (back >= 1 && t - COLLAPSE_BACK - ft.delay2 < 122 && ft.cen) fxImpactOnce(ft);
      break;
    }
  }
  // gently home when a visitor arrives (on a moving slab of stone it rides home with its wall)
  if (fxAbortAt >= 0 && !(stoneMode() && fxType == FX_TILT) && !(fxType == FX_SWAP && fxSwapDone)) {
    float k = smooth01((frameCount - fxAbortAt) / 50.0);
    Face f = faces[ft.face];
    ft.C.lerp(ft.home, k);
    ft.bx.lerp(f.eU, k).normalize(); ft.by.lerp(f.eV, k).normalize(); ft.bz.lerp(f.n, k).normalize();
    ft.alpha = lerp(ft.alpha, 1, k);
  }
  // its outline this frame, and how far it is from home
  for (int k = 0; k < ft.xs.length; k++) {
    float ox = ft.xs[k] - ft.cx, oy = ft.ys[k] - ft.cy;
    ft.vx[k] = ft.C.x + ft.bx.x * ox + ft.by.x * oy;
    ft.vy[k] = ft.C.y + ft.bx.y * ox + ft.by.y * oy;
    ft.vz[k] = ft.C.z + ft.bx.z * ox + ft.by.z * oy;
  }
  Face f = faces[ft.face];
  ft.lift = PVector.sub(ft.C, ft.home).dot(f.n);
  ft.disp = PVector.dist(ft.C, ft.home) + (2 - ft.bz.dot(f.n) - ft.bx.dot(f.eU)) * ft.rad;
  // out in the room or painted on its wall: once out it stays out until it has really been still a while
  // (a tile bouncing through its place would otherwise flick to the wall for a single frame)
  ft.still = ft.disp < 0.25 ? ft.still + 1 : 0;
  ft.moved = ft.moved ? ft.still < 10 : ft.disp > 1.5;
}

// wave: as its crest passes the middle of each wall, the clatter of its tiles (the cue sound plays as it
// sets off: SoundEngine.pde)
float waveCrestPrev = -1e9;
void waveSounds(int t) {
  if (t < 0 || fxAbortAt >= 0) { waveCrestPrev = -1e9; return; }
  float ring = 2 * (ROOM_W + ROOM_D);
  float X = lerp(-1400, ring + 1400, t / (float) (fxDur - 40));   // (as in poseTile: FX_WAVE)
  for (int w = 1; w <= 4; w++) {
    float c = ringFrom(moteRingStart(w) + faces[w].w / 2);
    if (waveCrestPrev < c && X >= c) wallMomentHit("wave");
  }
  waveCrestPrev = X;
}

// heartbeat: one slow swell — out, a breath, back with a soft settle
final float HEART_GAP = 55;
ArrayList<float[]> fxSeeds = new ArrayList<float[]>();   // face, x, y, when
float swell(float x) {
  if (x <= 0) return 0;
  if (x < 34) return easeOutCubic01(x / 34);
  x -= 34;
  if (x < 18) return 1;
  x -= 18;
  if (x < 64) return 1 - smooth01(x / 64);
  x -= 64;
  return -0.08 * sin(PI * min(1, x / 18)) * exp(-x / 20);
}

float easeOutCubic01(float x) { x = constrain(x, 0, 1); return 1 - pow(1 - x, 3); }

// Collapse: where it falls. On the floor, a little into the room (face up mostly, sometimes face down,
// showing its unglazed back), turned; with no floor, down the wall to its foot, leaning there.
void planFall(FxTile t) {
  Face f = faces[t.face];
  PVector bx0 = f.eU.copy(), by0 = f.eV.copy(), bz0 = f.n.copy(), bx1, by1, bz1;
  if (HAS_FLOOR) {
    boolean up = true;   // (always its glaze to the room: a tile lying face down only showed its clay)
    float yaw = random(-1.1, 1.1);
    t.landC = PVector.add(PVector.add(new PVector(t.home.x, t.home.y, 0), PVector.mult(f.n, random(150, 560))), PVector.mult(f.eU, random(-170, 170)));
    t.landC.z = up ? fxT() : 0.6;
    bz1 = new PVector(0, 0, up ? 1 : -1);
    bx1 = new PVector(f.eU.x * cos(yaw) - f.eU.y * sin(yaw), f.eU.x * sin(yaw) + f.eU.y * cos(yaw), 0);
    by1 = bz1.cross(bx1);
    t.T1 = round(20 + 26 * sqrt(t.home.z / WALL_H));
  } else {
    float rz = random(-0.7, 0.7);
    PVector foot = f.toRoom(t.cx + random(-90, 90), WALL_H - t.rad * 0.6 - random(0, 50));
    t.landC = PVector.add(foot, PVector.mult(f.n, fxT() + random(4, 30)));
    bx1 = PVector.add(PVector.mult(bx0, cos(rz)), PVector.mult(by0, sin(rz)));
    by1 = PVector.add(PVector.mult(bx0, -sin(rz)), PVector.mult(by0, cos(rz)));
    bz1 = bz0.copy();
    t.T1 = round(16 + 24 * sqrt(max(0, t.home.z - t.landC.z) / WALL_H));
  }
  t.turn = turnBetween(bx0, by0, bz0, bx1, by1, bz1);
}

// the tile at tau frames into its fall (deterministic: the way back is the same path)
void poseFall(FxTile ft, float tau) {
  Face f = faces[ft.face];
  float s = min(tau, ft.T1) / ft.T1;
  // out at a steady pace, down faster and faster (from rest): it drops like a real thing
  ft.C.set(lerp(ft.home.x, ft.landC.x, s), lerp(ft.home.y, ft.landC.y, s), ft.home.z + (ft.landC.z - ft.home.z) * s * s);
  float b = tau - ft.T1;
  if (b > 0) {   // a little jump where it lands, and a short slide
    ft.C.z += (HAS_FLOOR ? 13 : 5) * abs(sin(PI * b / 9)) * exp(-b / 6);
    ft.C.add(PVector.mult(HAS_FLOOR ? f.n : f.eV, 16 * (1 - exp(-b / 7))));
  }
  float r = easeInOutCubic(s);
  ft.bx.set(rotAbout(f.eU, ft.turn, r)); ft.by.set(rotAbout(f.eV, ft.turn, r)); ft.bz.set(rotAbout(f.n, ft.turn, r));
  if (b > 0 && b < 2) wallMomentHit("collapse");
}

// back from the floor: up and round in an arc (out into the room, high, and in again to its place),
// turning upright on the way, a whole turn about itself
void poseReturn(FxTile ft, float back) {
  Face f = faces[ft.face];
  poseFall(ft, ft.T1 + 26);
  PVector P0 = ft.C.copy(), P3 = ft.home;
  PVector E = viewerEye();
  PVector side = PVector.mult(f.eU, ft.a * WALL_H * 0.5);
  PVector P1 = PVector.add(PVector.add(P0, new PVector(0, 0, WALL_H * 0.75)), PVector.add(PVector.mult(PVector.sub(E, P0), 0.25), side));
  PVector P2 = PVector.add(PVector.add(P3, PVector.mult(f.n, WALL_H * 0.55)), new PVector(0, 0, WALL_H * 0.2));
  float e = easeInOutCubic(back), a = 1 - e;
  ft.C.set(P0.x * a * a * a + 3 * P1.x * a * a * e + 3 * P2.x * a * e * e + P3.x * e * e * e,
           P0.y * a * a * a + 3 * P1.y * a * a * e + 3 * P2.y * a * e * e + P3.y * e * e * e,
           P0.z * a * a * a + 3 * P1.z * a * a * e + 3 * P2.z * a * e * e + P3.z * e * e * e);
  float r = 1 - smooth01(constrain(back * 1.15, 0, 1));   // upright again a little before it arrives
  PVector bx = rotAbout(f.eU, ft.turn, r), by = rotAbout(f.eV, ft.turn, r), bz = rotAbout(f.n, ft.turn, r);
  float spin = TWO_PI * (ft.b < 0 ? -1 : 1) * smooth01(back);   // a whole turn on itself, in its own plane
  ft.bx.set(PVector.add(PVector.mult(bx, cos(spin)), PVector.mult(by, sin(spin))));
  ft.by.set(PVector.add(PVector.mult(bx, -sin(spin)), PVector.mult(by, cos(spin))));
  ft.bz.set(bz);
}

// the rotation taking one frame (bx0, by0, bz0) to another, as axis and angle
float[] turnBetween(PVector bx0, PVector by0, PVector bz0, PVector bx1, PVector by1, PVector bz1) {
  float[][] R = new float[3][3];
  PVector[] A = { bx0, by0, bz0 }, B = { bx1, by1, bz1 };
  for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) {
    float v = 0;
    for (int k = 0; k < 3; k++) v += B[k].array()[i] * A[k].array()[j];
    R[i][j] = v;
  }
  float c = constrain((R[0][0] + R[1][1] + R[2][2] - 1) / 2, -1, 1), ang = acos(c);
  PVector ax = new PVector(R[2][1] - R[1][2], R[0][2] - R[2][0], R[1][0] - R[0][1]);
  if (ax.mag() < 1e-4) {   // no turn, or half a turn: the axis from the diagonal
    if (ang < 0.01) return new float[] { 1, 0, 0, 0 };
    int k = R[0][0] > R[1][1] ? (R[0][0] > R[2][2] ? 0 : 2) : (R[1][1] > R[2][2] ? 1 : 2);
    ax = new PVector(sqrt(max(0, (R[0][0] + 1) / 2)), sqrt(max(0, (R[1][1] + 1) / 2)), sqrt(max(0, (R[2][2] + 1) / 2)));
    if (k == 0) { ax.y = copySign(ax.y, R[0][1]); ax.z = copySign(ax.z, R[0][2]); }
    if (k == 1) { ax.x = copySign(ax.x, R[0][1]); ax.z = copySign(ax.z, R[1][2]); }
    if (k == 2) { ax.x = copySign(ax.x, R[0][2]); ax.y = copySign(ax.y, R[1][2]); }
  }
  ax.normalize();
  return new float[] { ax.x, ax.y, ax.z, ang };
}
float copySign(float m, float s) { return s < 0 ? -abs(m) : abs(m); }

// v turned by the share r of the turn (Rodrigues)
PVector rotAbout(PVector v, float[] turn, float r) {
  PVector k = new PVector(turn[0], turn[1], turn[2]);
  float a = turn[3] * r, c = cos(a), s = sin(a);
  PVector out = PVector.mult(v, c);
  out.add(PVector.mult(k.cross(v), s));
  out.add(PVector.mult(k, k.dot(v) * (1 - c)));
  return out;
}

// The walls fall over the audience about their foot: the far wall, then the two side walls together
// (opposite each other: their ends slide along the walls that stay up, so no two walls ever go through
// each other), then — not on stone, where the word stays — the main wall. Each one falls faster and
// faster, is caught with a jolt, hangs there, and is pushed slowly back up into its place.
final int TILT_STAGE = 255;
void poseTilt(int t) {
  int[][] stages = { { W1 }, { W2, W4 }, { W3 } };
  int n = stoneMode() ? 2 : 3;
  for (int i = 0; i < n; i++) {
    float x = t - i * TILT_STAGE;
    for (int w : stages[i]) {
      fxWallTilt[w] = radians(34) * S() * (w == W3 ? 0.7 : 1) * fallCatch(x);
      if (x == 40 || x == 40 + 110 + 95) fxImpact(w, faces[w].w / 2, WALL_H * 0.5);
    }
  }
}
float fallCatch(float x) {
  if (x <= 0) return 0;
  if (x < 40) return sq(x / 40);                                       // falling
  x -= 40;
  if (x < 110) return 1 - 0.09 * exp(-x / 9) * cos(x * 0.55) + 0.004 * sin(x * 1.7);   // caught: a jolt, then it hangs, creaking
  x -= 110;
  if (x < 95) return 1 - easeInOutCubic(x / 95);                        // pushed back up
  x -= 95;
  return -0.03 * exp(-x / 6) * sin(x * 0.8);                             // into its place: a thud
}

// A tile at (du, dv) from its place on its wall, d towards the room, turned by rx, ry, rz
// (and with its whole wall leaning, fxWallTilt)
void wallPose(FxTile ft, float du, float dv, float d, float rx, float ry, float rz) {
  Face f = faces[ft.face];
  float[] ex = rot3(1, 0, 0, rx, ry, rz), ey = rot3(0, 1, 0, rx, ry, rz), ez = rot3(0, 0, 1, rx, ry, rz);
  float u = ft.cx + du, v = ft.cy + dv, w = d + fxT();   // (its face stands its body's thickness off the wall)
  float th = fxWallTilt[ft.face];
  if (th != 0) {   // about the wall's foot (v = WALL_H, w = 0): its top comes into the room
    float c = cos(th), s = sin(th), H = WALL_H;
    float v2 = H + (v - H) * c + w * s, w2 = -(v - H) * s + w * c;
    v = v2; w = w2;
    for (float[] e : new float[][] { ex, ey, ez }) { float ev = e[1] * c + e[2] * s, ew = -e[1] * s + e[2] * c; e[1] = ev; e[2] = ew; }
  }
  ft.C.set(f.O.x + f.eU.x * u + f.eV.x * v + f.n.x * w, f.O.y + f.eU.y * u + f.eV.y * v + f.n.y * w, f.O.z + f.eU.z * u + f.eV.z * v + f.n.z * w);
  toRoomDir(f, ex, ft.bx); toRoomDir(f, ey, ft.by); toRoomDir(f, ez, ft.bz);
}

void toRoomDir(Face f, float[] e, PVector out) {
  out.set(f.eU.x * e[0] + f.eV.x * e[1] + f.n.x * e[2], f.eU.y * e[0] + f.eV.y * e[1] + f.n.y * e[2], f.eU.z * e[0] + f.eV.z * e[1] + f.n.z * e[2]);
}

float[] rot3(float x, float y, float z, float rx, float ry, float rz) {
  float c = cos(ry), s = sin(ry);
  float x1 = x * c + z * s, z1 = -x * s + z * c;
  c = cos(rx); s = sin(rx);
  float y2 = y * c - z1 * s, z2 = y * s + z1 * c;
  c = cos(rz); s = sin(rz);
  return new float[] { x1 * c - y2 * s, x1 * s + y2 * c, z2 };
}

// Swap: out of its wall, across the room (a curve that comes towards the audience) turning over once
// like a coin, into its partner's place — for good. The mural itself changes (swapInMural): each word is
// re-made in the other's place, in its shape. When the tile is edge on in the air it takes that shape
// and that picture, unseen; it lands in its new place exactly as the mural now has it.
final int SWAP_OUT = 36, SWAP_FLY = 230, SWAP_IN = 40;
boolean fxSwapDone = false;
int fxAbortT = -1;
PGraphics[] swapOld = new PGraphics[5], swapOldGloss = new PGraphics[5];   // the mural as it was (the tiles' pictures until they turn)

int sizeKind(JSONObject r) {
  if (r == null) return -1;
  int p = r.getInt("part", PART_WHOLE);
  return p == PART_WHOLE ? 0 : (p == PART_MERGED ? 2 : 1);
}

// While the room announces the moment: each word is made again in the other's place, in a thread of its
// own (only pictures in memory: no drawing), so the room never stutters
volatile boolean swapReady = false;
void prepareSwapTiles() {
  swapReady = false;
  final ArrayList<FxTile> list = new ArrayList<FxTile>(fxTiles);
  for (FxTile A : list) {
    FxTile B = A.partner;
    if (A.rec == null || B == null || B.rec == null) continue;
    A.remadeRec = JSONObject.parse(A.rec.toString());
    setSlot(A.remadeRec, B.rec.getInt("slot"), B.rec.getInt("part", PART_WHOLE), B.rec.getInt("slot2", -1));
    A.remadeN = 0;
    for (int i = 0; i < mosaicTiles.size(); i++) if (mosaicTiles.getJSONObject(i) == A.rec) A.remadeN = i;
  }
  new Thread(new Runnable() { public void run() {
    try { for (FxTile A : list) if (A.remadeRec != null) A.remade = tileFor(A.remadeRec, A.remadeRec.getInt("n", A.remadeN)); }
    catch (Exception e) { println("Swap: could not make the tiles again (" + e + ")"); }
    swapReady = true;
  } }).start();
}

// once, as the tiles leave (before the walls are drawn): the words change places in the mural
void swapInMural() {
  fxSwapDone = true;
  boolean[] used = new boolean[5];
  for (FxTile t : fxTiles) used[t.face] = true;
  for (int w = 1; w <= 4; w++) if (used[w]) {   // the old pictures, for the flight's first half
    swapOld[w] = copyLayer(swapOld[w], mosaicLayers[w]);
    swapOldGloss[w] = copyLayer(swapOldGloss[w], glossLayers[w]);
  }
  for (FxTile t : fxTiles) { t.col = swapOld[t.face]; t.rel = swapOldGloss[t.face]; t.force = true; }
}
// then one pair a frame (re-making a tile takes a moment: spread out, no stutter) — long before any of
// them turns over in the air
void swapNextPair() {
  if (!fxSwapDone || !swapReady) return;
  for (FxTile A : fxTiles) {
    FxTile B = A.partner;
    if (A.rec == null || B == null || B.rec == null || A.dest != null) continue;
    if (A.remade == null || B.remade == null) { A.partner = B.partner = null; A.force = B.force = false; A.col = mosaicLayers[A.face]; B.col = mosaicLayers[B.face]; continue; }   // (could not: they stay)
    wipeSlot(A.face, A.xs, A.ys); wipeSlot(B.face, B.xs, B.ys);
    for (FxTile T : new FxTile[] { A, B }) {
      setSlot(T.rec, T.remadeRec.getInt("slot"), T.remadeRec.getInt("part", PART_WHOLE), T.remadeRec.getInt("slot2", -1));
      stampTile(T.remade);
    }
    A.dest = fxTile(B.face, B.xs, B.ys, mosaicLayers[B.face], glossLayers[B.face], faces[B.face].h, false, B.band);
    B.dest = fxTile(A.face, A.xs, A.ys, mosaicLayers[A.face], glossLayers[A.face], faces[A.face].h, false, A.band);
    for (FxTile t : fxTiles) if (t.dest == null && t.partner != null && t.partner.rec != null) return;   // more to come
    saveMosaic();
    return;
  }
}

void setSlot(JSONObject r, int slot, int part, int slot2) {
  r.setInt("slot", slot); r.setInt("part", part);
  if (slot2 >= 0) r.setInt("slot2", slot2); else if (r.hasKey("slot2")) r.remove("slot2");
}

PGraphics copyLayer(PGraphics c, PGraphics L) {
  if (L == null) return null;
  if (c == null || c.width != L.width || c.height != L.height) c = createGraphics(L.width, L.height, P2D);
  c.beginDraw();
  c.clear();
  c.blendMode(REPLACE);
  c.image(L, 0, 0);
  c.blendMode(BLEND);
  c.endDraw();
  return c;
}

void wipeSlot(int face, float[] xs, float[] ys) {
  float s = RENDER_SCALE;
  for (PGraphics G : new PGraphics[] { mosaicLayers[face], glossLayers[face] }) {
    if (G == null) continue;
    G.beginDraw();
    G.blendMode(REPLACE);
    G.noStroke();
    G.fill(0, 0);
    G.beginShape();
    for (int k = 0; k < xs.length; k++) G.vertex(xs[k] * s, ys[k] * s);
    G.endShape(CLOSE);
    G.blendMode(BLEND);
    G.endDraw();
  }
}

// it takes the shape and the picture of its new place (edge on, unseen)
void takeDest(FxTile A) {
  if (A.switched || A.dest == null) return;
  A.switched = true;
  FxTile D = A.dest;
  A.face = D.face; A.src = D.face; A.xs = D.xs; A.ys = D.ys; A.cx = D.cx; A.cy = D.cy; A.rad = D.rad;
  A.col = D.col; A.rel = D.rel; A.layerH = D.layerH; A.band = D.band;
  A.home = D.home; A.homeP = D.homeP; A.vx = D.vx; A.vy = D.vy; A.vz = D.vz; A.ringX = D.ringX;
}

void poseSwap(FxTile A, float t) {
  float out = WALL_H * 0.12 * S();
  if (t < 0 || A.partner == null) { wallPose(A, 0, 0, 0, 0, 0, 0); return; }
  if (t < SWAP_OUT) { wallPose(A, 0, 0, out * easeOutCubic01(t / SWAP_OUT), 0, 0, 0); return; }
  if (t >= SWAP_OUT + SWAP_FLY) {   // into its new place
    takeDest(A);
    float k = (t - SWAP_OUT - SWAP_FLY) / SWAP_IN;
    wallPose(A, 0, 0, out * (1 - easeOutCubic01(k)) - 6 * sin(PI * constrain(k * 1.4 - 0.4, 0, 1)), 0, 0, 0);   // pressed home
    if (k >= 1) A.force = false;
    if (t == SWAP_OUT + SWAP_FLY + SWAP_IN - 6) fxImpactOnce(A);
    return;
  }
  // the flight: from its own wall (as it was) to the other's place
  float go = (t - SWAP_OUT) / SWAP_FLY, e = easeInOutCubic(go);
  float flip = smooth01((go - 0.3) / 0.4);   // mid-flight it tips onto its edge and back: its face always to the room
  if (flip >= 0.5) takeDest(A);   // edge on: it takes its new shape unseen
  Face fa = faces[A.fromFace], fb = faces[A.toFace];
  PVector E = viewerEye();
  PVector P0 = PVector.add(A.fromHome, PVector.mult(fa.n, out)), P3 = PVector.add(A.toHome, PVector.mult(fb.n, out));
  PVector P1 = PVector.lerp(P0, E, 0.4), P2 = PVector.lerp(P3, E, 0.4);
  float a = 1 - e;
  A.C.set(P0.x * a * a * a + 3 * P1.x * a * a * e + 3 * P2.x * a * e * e + P3.x * e * e * e,
          P0.y * a * a * a + 3 * P1.y * a * a * e + 3 * P2.y * a * e * e + P3.y * e * e * e,
          P0.z * a * a * a + 3 * P1.z * a * a * e + 3 * P2.z * a * e * e + P3.z * e * e * e);
  PVector bx = PVector.lerp(fa.eU, fb.eU, e), by = PVector.lerp(fa.eV, fb.eV, e);
  bx.normalize(); PVector bz = bx.cross(by); bz.normalize(); by = bz.cross(bx);
  float phi = HALF_PI * sin(PI * flip) * A.a;   // tipping about its own width up to edge on (a quarter turn) and back
  A.bx.set(bx);
  A.by.set(PVector.add(PVector.mult(by, cos(phi)), PVector.mult(bz, sin(phi))));
  A.bz.set(PVector.add(PVector.mult(by, -sin(phi)), PVector.mult(bz, cos(phi))));
}

// a light and a wave along the mural where something lands (Mural.pde)
void fxImpact(int face, float x, float y) {
  float ro = ringOffsetOf(face);
  if (ro >= 0) waves.add(new float[] { ro + x, y, frameCount });
  impacts.add(new float[] { face, x, y, frameCount });
  wallMomentHit(FX_NAMES[max(0, fxType)]);
}
boolean[] fxHitDone = new boolean[5];
int fxHitFrame = -1;
void fxImpactOnce(FxTile ft) {   // once per wall per frame-moment
  if (fxHitFrame != fxStart) { fxHitFrame = fxStart; fxHitDone = new boolean[5]; }
  if (fxHitDone[ft.face]) return;
  fxHitDone[ft.face] = true;
  fxImpact(ft.face, faces[ft.face].w / 2, ft.cen ? WALL_H * CENEFA_H * 0.5 : WALL_H * 0.5);
}

// ── Drawing ─────────────────────────────────────────────────

// What is under a tile that has left, at (ox, oy) from its place: the stone of the wall, or the smoke;
// k how much (it fades in as the tile comes away)
void behindPatch(PGraphics pg, Face f, FxTile ft, float ox, float oy, float k) {
  if (k < 0.01) return;
  boolean stone = stoneMode() && stoneNormals[f.id] != null;
  boolean glow = !stone && glowOn() && smokeBufs[f.id] != null;
  pg.noStroke();
  if (!stone && !glow) {
    pg.fill(hexColor(BACKGROUND_COLOR), 100 * k);
    fan(pg, ft.xs, ft.ys, ft.cx, ft.cy, ox, oy);
    return;
  }
  pg.textureMode(NORMAL);
  if (stone) { PShader sh = stoneLightShader(); stoneUniforms(sh, f, 1 - 0.4 * fxDim, k); pg.shader(sh); }
  else pg.tint(0, 0, 100, 100 * k);
  pg.beginShape(TRIANGLE_FAN);
  pg.texture(smokeBufs[f.id]);
  pg.vertex(ft.cx + ox, ft.cy + oy, constrain((ft.cx + ox) / f.w, 0, 1), constrain((ft.cy + oy) / f.h, 0, 1));
  for (int q = 0; q <= ft.xs.length; q++) {
    int i = q % ft.xs.length;
    float x = ft.xs[i] + ox, y = ft.ys[i] + oy;
    pg.vertex(x, y, constrain(x / f.w, 0, 1), constrain(y / f.h, 0, 1));
  }
  pg.endShape();
  if (stone) pg.resetShader(); else pg.noTint();
}

// Before the mural (Room.pde, just after its body is drawn): the body's band the layer still draws for a
// tile that has left (thickness.glsl reads the layer, where the tile still is) is covered with what is
// under it — no ghost of its side stays on the wall. Its neighbours are drawn after, over it: theirs stay.
void drawWallMomentsUnder(PGraphics pg, Face f) {
  if (fxType < 0 || f.id == FLOOR || MURAL_THICK <= 0 || fxSlab(f.id)) return;
  float ox = MURAL_THICK * 0.38 * 1.15, oy = MURAL_THICK * 0.92 * 1.15;
  for (FxTile ft : fxTiles) {
    if (!(ft.moved || ft.force) || ft.face != f.id) continue;
    float k = ft.force ? 1 : constrain(ft.disp / 25, 0, 1);
    for (int i = 1; i <= 3; i++) behindPatch(pg, f, ft, ox * i / 3, oy * i / 3, k);
  }
}

// On the wall itself (flat camera, after the mural and the border): where a tile was — on stone the
// stone itself with the bed of lime mortar it was set in; otherwise its dark bed — and its shadow
void drawWallMomentsFlat(PGraphics pg, Face f) {
  if (fxType < 0) return;
  if (fxSlab(f.id)) return;     // the whole wall is moving: nothing stays on it
  boolean stone = stoneMode() && f.id != FLOOR;
  int bed = hexColor(stone ? GROUT_COLOR : FX_BED_COLOR);
  pg.noStroke();
  for (FxTile ft : fxTiles) {
    if (!(ft.moved || ft.force) || ft.face != f.id) continue;
    float k = ft.force ? 1 : constrain(ft.disp / 25, 0, 1);
    if (stone) {
      behindPatch(pg, f, ft, 0, 0, k);
      pg.fill(bed, 30 * k);
      fan(pg, ft.xs, ft.ys, ft.cx, ft.cy, 0, 0);
      bedShade(pg, ft, k);   // a shallow bed: a touch of shade inside its upper left edges (never outside it)
    } else {
      pg.fill(bed, 100 * k * (backdropOn() ? WALL_MOMENTS_BED : 1));   // with the smoke: it shows through the bare wall
      fan(pg, ft.xs, ft.ys, ft.cx, ft.cy, 0, 0);
    }
  }
  if (fxType == FX_TILT) return;   // (a whole wall moving: there is no wall behind it to fall on)
  for (FxTile ft : fxTiles) {   // the shadow it casts on the wall, falling down and to the right (light from the upper left)
    if (!ft.moved || ft.face != f.id || ft.lift <= 1) continue;
    // close to the wall a crisp shadow next to it; further out it spreads, pales and is gone (never a dark
    // copy of the tile sliding across the wall)
    float far = smooth01((ft.lift - 140) / 260.0), drop = smooth01((ft.home.z - ft.C.z) / (WALL_H * 0.3));
    float k = min(1, ft.lift / 90.0) * ft.alpha * (1 - far) * (1 - drop);
    if (k < 0.01) continue;
    float l = min(ft.lift, 200);
    pg.fill(0, 0, 0, 38 * k);
    fan(pg, ft.xs, ft.ys, ft.cx, ft.cy, l * 0.22, l * 0.38);
  }
}

// inside the outline only: a band of shade along the edges facing the light (upper left), fading inwards
void bedShade(PGraphics pg, FxTile ft, float k) {
  int n = ft.xs.length;
  float bw = 9;
  pg.beginShape(QUADS);
  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    float ex = ft.xs[j] - ft.xs[i], ey = ft.ys[j] - ft.ys[i], l = max(0.001, sqrt(ex * ex + ey * ey));
    float nx = ey / l, ny = -ex / l;
    if (nx * ((ft.xs[i] + ft.xs[j]) / 2 - ft.cx) + ny * ((ft.ys[i] + ft.ys[j]) / 2 - ft.cy) < 0) { nx = -nx; ny = -ny; }
    float facing = nx * -0.6 + ny * -0.8;
    if (facing < 0.1) continue;
    float ki = min(0.45, bw / max(1, dist(ft.xs[i], ft.ys[i], ft.cx, ft.cy))), kj = min(0.45, bw / max(1, dist(ft.xs[j], ft.ys[j], ft.cx, ft.cy)));
    pg.fill(0, 0, 0, 30 * k * facing);
    pg.vertex(ft.xs[i], ft.ys[i]); pg.vertex(ft.xs[j], ft.ys[j]);
    pg.fill(0, 0, 0, 0);
    pg.vertex(lerp(ft.xs[j], ft.cx, kj), lerp(ft.ys[j], ft.cy, kj)); pg.vertex(lerp(ft.xs[i], ft.cx, ki), lerp(ft.ys[i], ft.cy, ki));
  }
  pg.endShape();
}

// Does a tile out of its wall show on another surface? (StoneMoments.pde: reachesFace)
boolean fxReaches(FxTile ft, Face g) { return ft.face != g.id && reachesFace(ft.C, faces[ft.face], ft.rad * 2.5 + abs(ft.lift), g); }

void fan(PGraphics pg, float[] xs, float[] ys, float cx, float cy, float ox, float oy) {
  pg.beginShape(TRIANGLE_FAN);
  pg.vertex(cx + ox, cy + oy);
  for (int k = 0; k <= xs.length; k++) pg.vertex(xs[k % xs.length] + ox, ys[k % xs.length] + oy);
  pg.endShape();
}

// In the room (the audience's camera): on the floor the shadows;
// the walls falling over the floor; and the tiles — each a real piece
// of tile: its glazed face, its body (MURAL_THICK) glazed down the sides in its own colours, its
// unglazed back when it turns over, and the pillar of wall it rides on when it comes out on a column
ArrayList<FxTile> fxDrawList = new ArrayList<FxTile>();

void drawWallMoments3D(PGraphics pg, Face f) {
  if (fxType < 0) return;
  PVector E = viewerEye();
  if (f.id == FLOOR) {
    viewerCamera(pg, f);
    drawFloorShadows(pg, f);   // StoneMoments.pde
  }
  if (!fxSlab(f.id) && slabReaches(f)) drawSlabs(pg, f);   // StoneMoments.pde: a wall leaning over this surface, in front of what is on it
  viewerCamera(pg, f);
  pg.hint(ENABLE_DEPTH_TEST);   // the blocks and tiles hide each other as they really do (no order to flip: no flicker)
  fxDrawList.clear();
  for (FxTile ft : fxTiles) {
    if (!ft.moved && !ft.force && !fxSlab(ft.face)) continue;
    if (ft.face != f.id && !fxReaches(ft, f)) continue;   // only where it is seen (the neighbouring walls near the corners, the floor)
    // (a tile still on its wall — the wave, the heartbeat — is not drawn on the floor: stretched over it at the
    // floor's resolution its glaze and edges shimmered, and the stretch only lines up from the viewer's spot)
    if (f.id == FLOOR && (fxType == FX_WAVE || fxType == FX_HEART)) continue;
    fxDrawList.add(ft);
  }
  if (fxDrawList.size() == 0) { pg.hint(DISABLE_DEPTH_TEST); flatCamera(pg, f); return; }
  java.util.Collections.sort(fxDrawList, (p, q) -> Float.compare(PVector.dist(q.C, E), PVector.dist(p.C, E)));   // the furthest first
  viewerCamera(pg, f);
  pg.noStroke();
  pg.textureMode(NORMAL);
  float T = fxT();
  boolean stone = stoneMode();
  float[] bedc = hsbOf(FX_BED_COLOR), clay = hsbOf(BODY_TERRACOTTA);
  for (FxTile ft : fxDrawList) {
    Face sf = faces[ft.face];
    int n = ft.xs.length;
    PVector Lf = PVector.add(PVector.mult(sf.eU, -0.5), PVector.mult(sf.eV, -0.85));   // the mural's light: from the upper left
    Lf.add(PVector.mult(sf.n, 0.35));
    Lf.normalize();
    boolean inside = ft.lift < 0;   // sunk into the wall: what shows is the inside of its hole (from its face to the wall)
    PVector[] back = new PVector[n], foot = new PVector[n];
    PVector[] face = new PVector[n];
    for (int k = 0; k < n; k++) {
      face[k] = new PVector(ft.vx[k], ft.vy[k], ft.vz[k]);
      back[k] = PVector.sub(face[k], PVector.mult(ft.bz, T));
      foot[k] = slabPoint(ft.face, ft.xs[k], ft.ys[k], 0);
    }
    // a column (out of the wall, or into it): the pillar of wall under it — stone (its own stone drawn
    // out along it), or mortar
    if (ft.column && abs(ft.lift) > 1) {
      for (int i = 0; i < n; i++) {
        int j = (i + 1) % n;
        float nx = ft.ys[j] - ft.ys[i], ny = -(ft.xs[j] - ft.xs[i]), l = max(0.001, sqrt(nx * nx + ny * ny));
        nx /= l; ny /= l;
        if (nx * ((ft.xs[i] + ft.xs[j]) / 2 - ft.cx) + ny * ((ft.ys[i] + ft.ys[j]) / 2 - ft.cy) < 0) { nx = -nx; ny = -ny; }   // outwards
        PVector sN = PVector.add(PVector.mult(sf.eU, nx), PVector.mult(sf.eV, ny));
        if (inside) sN.mult(-1);   // inside a hole the far walls show, facing in
        PVector top_i = inside ? face[i] : back[i], top_j = inside ? face[j] : back[j];
        PVector mid = PVector.lerp(top_i, foot[j], 0.5);
        if (sN.dot(PVector.sub(E, mid)) <= 0) continue;
        float lit = constrain(0.66 + 0.36 * sN.dot(Lf), 0.32, 1) * (inside ? 0.8 : 1) * (1 - 0.3 * fxDim);   // (the side in shade still shows its stone)
        float len = abs(ft.lift);
        if (stone) {   // (a tint holds for a whole shape: one shape per side)
          pg.tint(0, 0, 100 * constrain(lit * STONE_LEVEL, 0, 1), 100 * ft.alpha);
          pg.beginShape(QUADS);
          pg.texture(smokeBufs[ft.face]);
          float s = inside ? -0.4 : 0.4;
          pg.vertex(top_i.x, top_i.y, top_i.z, constrain(ft.xs[i] / sf.w, 0, 1), constrain(ft.ys[i] / sf.h, 0, 1));
          pg.vertex(top_j.x, top_j.y, top_j.z, constrain(ft.xs[j] / sf.w, 0, 1), constrain(ft.ys[j] / sf.h, 0, 1));
          pg.vertex(foot[j].x, foot[j].y, foot[j].z, constrain((ft.xs[j] + nx * len * s) / sf.w, 0, 1), constrain((ft.ys[j] + ny * len * s) / sf.h, 0, 1));
          pg.vertex(foot[i].x, foot[i].y, foot[i].z, constrain((ft.xs[i] + nx * len * s) / sf.w, 0, 1), constrain((ft.ys[i] + ny * len * s) / sf.h, 0, 1));
          pg.endShape();
          pg.noTint();
        } else {
          pg.fill(bedc[0], bedc[1] * 0.85, bedc[2] * lit * 0.8, 100 * ft.alpha);
          pg.beginShape(QUADS);
          pg.vertex(top_i.x, top_i.y, top_i.z); pg.vertex(top_j.x, top_j.y, top_j.z);
          pg.vertex(foot[j].x, foot[j].y, foot[j].z); pg.vertex(foot[i].x, foot[i].y, foot[i].z);
          pg.endShape();
        }
      }
    }
  }
  // its body, as it looks on the wall (thickness.glsl): the glaze rolling down its edge in its own colours,
  // a band down and to the right of the face, darker further back — carried along as the tile moves
  for (FxTile ft : fxDrawList) {
    if (!facesEye(ft, E)) continue;
    PGraphics soft = softOf(ft.col == swapOld[ft.src] || ft.col == null ? mosaicLayers[ft.src] : ft.col);
    if (soft == null) continue;
    Face sf = faces[ft.src];
    // as it comes out of the wall its edge shows more and more over its neighbours (they are still painted
    // on the wall: a whole band at once would flash over them); when the whole wall moves its neighbours
    // move too, and hide its band except in the joints, as on the wall
    boolean together = fxSlab(ft.face) || fxType == FX_TILT;
    float bk = together ? 1 : smooth01(max(0, ft.lift) / (2.5 * T) + (ft.force ? 1 : 0));   // (sunk into the wall its edge is hidden)
    if (bk < 0.02) continue;
    PVector ob = PVector.add(PVector.mult(ft.bx, 0.38 * T * bk), PVector.mult(ft.by, 0.92 * T * bk));
    ob.sub(PVector.mult(ft.bz, 0.6 * T * bk));
    int n = ft.xs.length, N = 5;   // (always the same: a lighter body when many were in the air popped in and out)
    for (int k = N; k >= 1; k--) {
      float fk = k / (float) N;
      pg.tint(0, 0, 100 * lerp(0.62, 0.36, fk), 100 * ft.alpha);
      pg.beginShape(TRIANGLE_FAN);
      pg.texture(soft);
      pg.vertex(ft.C.x + ob.x * fk, ft.C.y + ob.y * fk, ft.C.z + ob.z * fk, ft.cx / sf.w, ft.cy / ft.layerH);
      for (int q = 0; q <= n; q++) {
        int i = q % n;
        pg.vertex(ft.vx[i] + ob.x * fk, ft.vy[i] + ob.y * fk, ft.vz[i] + ob.z * fk,
                  (ft.cx + (ft.xs[i] - ft.cx) * 0.82) / sf.w, (ft.cy + (ft.ys[i] - ft.cy) * 0.82) / ft.layerH);   // its colour a little in from the edge
      }
      pg.endShape();
    }
    pg.noTint();
  }
  // the glazed faces (those turned to the audience), under the same live light as the mural (one shader per source layer)
  ArrayList<PGraphics> layers = new ArrayList<PGraphics>();
  for (FxTile ft : fxDrawList) if (facesEye(ft, E) && ft.col != null && !layers.contains(ft.col)) layers.add(ft.col);
  for (PGraphics layer : layers) {
    FxTile first = null;
    for (FxTile ft : fxDrawList) if (ft.col == layer && facesEye(ft, E)) { first = ft; break; }
    boolean lit = art(ART_MURAL_LIGHT) && first.rel != null;
    if (lit) pg.shader(muralShaderFor(faces[first.src], first.rel, first.layerH));
    for (FxTile ft : fxDrawList) {
      if (ft.col != layer || !facesEye(ft, E)) continue;
      Face sf = faces[ft.src];
      // lit from above: a face turning up catches the light, turning down goes dark; nearer is a touch brighter
      float shade = constrain(1 + 1.1 * ft.bz.z - 0.35 * (1 - ft.bz.dot(sf.n)) + 0.1 * constrain(ft.lift / 400, -1, 1), 0.3, 1.25);
      shade = min(shade, lerp(1.25, 1.12, smooth01((ft.bz.z - 0.3) / 0.4)));   // lying on the floor: lit, not blazing (eased in: no jump)
      pg.beginShape(TRIANGLE_FAN);
      pg.texture(ft.col);
      pg.tint(0, 0, 100 * min(1, shade), 100 * ft.alpha);
      ft.sheen = max(0, shade - 1) * ft.alpha;   // brighter than the wall: a warm sheen, added after
      int n = ft.xs.length;
      pg.vertex(ft.C.x, ft.C.y, ft.C.z, ft.cx / sf.w, ft.cy / ft.layerH);
      for (int k = 0; k <= n; k++) { int i = k % n; pg.vertex(ft.vx[i], ft.vy[i], ft.vz[i], ft.xs[i] / sf.w, ft.ys[i] / ft.layerH); }
      pg.endShape();
    }
    pg.noTint();
    if (lit) pg.resetShader();
  }
  // the glaze rounding over at its edge (as bevel.glsl on the wall): lighter along the edges facing the
  // light (upper left), darker along the others, fading in from the edge
  float bw = max(4, MURAL_BEVEL * 0.55);
  for (FxTile ft : fxDrawList) {
    if (!facesEye(ft, E)) continue;
    int n = ft.xs.length;
    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      float ex = ft.xs[j] - ft.xs[i], ey = ft.ys[j] - ft.ys[i], l = max(0.001, sqrt(ex * ex + ey * ey));
      float nx = ey / l, ny = -ex / l;
      if (nx * ((ft.xs[i] + ft.xs[j]) / 2 - ft.cx) + ny * ((ft.ys[i] + ft.ys[j]) / 2 - ft.cy) < 0) { nx = -nx; ny = -ny; }
      float facing = nx * -0.6 + ny * -0.8;
      if (abs(facing) < 0.08) continue;
      float a = (facing > 0 ? 34 * facing : 40 * -facing) * MURAL_BEVEL_LIGHT * ft.alpha, br = facing > 0 ? 100 : 0;
      float ki = min(0.45, bw / max(1, dist(ft.xs[i], ft.ys[i], ft.cx, ft.cy))), kj = min(0.45, bw / max(1, dist(ft.xs[j], ft.ys[j], ft.cx, ft.cy)));
      float ox = ft.bz.x * 0.5, oy = ft.bz.y * 0.5, oz = ft.bz.z * 0.5;   // (a hair over the face: never fighting it for the same depth)
      pg.beginShape(QUADS);
      pg.fill(0, 0, br, a);
      pg.vertex(ft.vx[i] + ox, ft.vy[i] + oy, ft.vz[i] + oz); pg.vertex(ft.vx[j] + ox, ft.vy[j] + oy, ft.vz[j] + oz);
      pg.fill(0, 0, br, 0);
      pg.vertex(lerp(ft.vx[j], ft.C.x, kj) + ox, lerp(ft.vy[j], ft.C.y, kj) + oy, lerp(ft.vz[j], ft.C.z, kj) + oz);
      pg.vertex(lerp(ft.vx[i], ft.C.x, ki) + ox, lerp(ft.vy[i], ft.C.y, ki) + oy, lerp(ft.vz[i], ft.C.z, ki) + oz);
      pg.endShape();
    }
  }
  // the backs of those turned over: unglazed fired clay, a little mortar still on it
  for (FxTile ft : fxDrawList) {
    if (facesEye(ft, E)) continue;
    ft.sheen = 0;
    float lit = constrain(0.55 + 0.45 * max(0, -ft.bz.z), 0.3, 1);
    Face sf = faces[ft.face];
    boolean grain = smokeBufs[ft.face] != null && backdropMode() == 2;
    if (grain) pg.tint(clay[0], clay[1] * 0.75, 100 * min(1, lit * 1.25), 100 * ft.alpha);   // its grain: the stone's, in the clay's colour
    else pg.fill(clay[0], clay[1] * 0.7, clay[2] * lit, 100 * ft.alpha);
    int n = ft.xs.length;
    pg.beginShape(TRIANGLE_FAN);
    if (grain) pg.texture(smokeBufs[ft.face]);
    PVector c = PVector.sub(ft.C, PVector.mult(ft.bz, T));
    if (grain) pg.vertex(c.x, c.y, c.z, ft.cx / sf.w, ft.cy / sf.h); else pg.vertex(c.x, c.y, c.z);
    for (int k = 0; k <= n; k++) {
      int i = k % n;
      float x = ft.vx[i] - ft.bz.x * T, y = ft.vy[i] - ft.bz.y * T, z = ft.vz[i] - ft.bz.z * T;
      if (grain) pg.vertex(x, y, z, constrain(ft.xs[i] / sf.w, 0, 1), constrain(ft.ys[i] / sf.h, 0, 1)); else pg.vertex(x, y, z);
    }
    pg.endShape();
    pg.noTint();
  }
  // the faces turning up to the light catch it (added on top)
  pg.blendMode(ADD);
  for (FxTile ft : fxDrawList) {
    if (ft.sheen < 0.01 || !facesEye(ft, E)) continue;
    pg.fill(40, 30, 100, 100 * min(1, ft.sheen * 1.6));
    int n = ft.xs.length;
    float ox = ft.bz.x * 0.8, oy = ft.bz.y * 0.8, oz = ft.bz.z * 0.8;
    pg.beginShape(TRIANGLE_FAN);
    pg.vertex(ft.C.x + ox, ft.C.y + oy, ft.C.z + oz);
    for (int k = 0; k <= n; k++) { int i = k % n; pg.vertex(ft.vx[i] + ox, ft.vy[i] + oy, ft.vz[i] + oz); }
    pg.endShape();
  }
  pg.blendMode(BLEND);
  pg.hint(DISABLE_DEPTH_TEST);
  flatCamera(pg, f);
}

boolean facesEye(FxTile ft, PVector E) { return ft.bz.dot(PVector.sub(E, ft.C)) > 0; }
