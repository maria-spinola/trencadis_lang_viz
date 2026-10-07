// ═══════════════════════════════════════════════════════════
// Mosaic.pde
// WALL 1 is the trencadís mural. It is divided once (fixed seed)
// into wavy bands of curved cells — the slots. Every word typed on
// the main wall becomes the tile of the next slot:
//
//   HOLD     its pieces assemble, big, in the middle of WALL 3
//   TRAVEL   it straightens up and comes apart: its pieces travel as a loose
//            cloud (split between WALL 2, WALL 4, FLOOR by emotion) to WALL 1
//   SET      in its slot, the grout seeps in under the shards and dries
//   landed   it is stamped into the mural (mosaicLayer) for good
//
// Slots fill from the centre outwards; when the wall is full it
// starts again over the oldest tiles. The placed words are saved in
// data/mosaic.json, so the mural survives a restart (Ctrl+N clears it).
// ═══════════════════════════════════════════════════════════

final int   FLIGHT_HOLD = 0, FLIGHT_TRAVEL = 1, FLIGHT_SET = 2;
final float TILT_FRAMES = 45;   // frames to straighten up before leaving the main wall

ArrayList<Patch> slots = new ArrayList<Patch>();
IntList slotBands = new IntList();
int[] slotOrder;                // fill order (indices into slots)
int mosaicCount = 0;            // tiles placed so far = next position in slotOrder
JSONArray mosaicTiles = new JSONArray();
PGraphics mosaicLayer;          // finished mural, WALL 1 pixels
ArrayList<TileFlight> flights = new ArrayList<TileFlight>();
float waveA, waveL, waveP1, waveP2;

void setupMosaic() {
  buildSlots();
  Face f = faces[W1];
  mosaicLayer = createGraphics(f.pg.width, f.pg.height, P2D);
  clearLayer();
  loadMosaic();
  println("Mosaic: " + slots.size() + " slots on " + f.name + ", " + mosaicCount + " tiles placed");
}

void updateMosaic() {
  for (int i = flights.size() - 1; i >= 0; i--) {
    flights.get(i).update();
    if (flights.get(i).landed) flights.remove(i);
  }
}

// Called by JSONLoader with the parameters of a new word
void spawnWordTile() {
  JSONObject rec = new JSONObject();
  rec.setInt("n",               mosaicCount);
  rec.setString("word",         currentWord);
  rec.setString("color_hex",    "#" + hex(pColorHex, 6));
  rec.setInt("emotion",         pEmotion);
  rec.setInt("word_class",      pWordClass);
  rec.setInt("abstraction",     pAbstract);
  rec.setInt("agency",          pAgency);
  rec.setInt("organic",         pOrganic);
  rec.setInt("phenomena_class", pPhenomenon);
  rec.setInt("time_duration",   pTime);
  mosaicTiles.append(rec);
  TrencadisTile tile = tileFor(rec, mosaicCount);
  mosaicCount++;
  saveMosaic();

  for (TileFlight fl : flights) if (fl.state == FLIGHT_HOLD) fl.depart();   // the previous word makes room
  flights.add(new TileFlight(tile, rec));
}

void clearMosaic() {
  mosaicTiles = new JSONArray();
  mosaicCount = 0;
  flights.clear();
  clearLayer();
  saveMosaic();
  println("Mosaic cleared");
}

// Ctrl+E. Leaving test mode drops the test tiles and restores the saved mural.
void toggleTestMode() {
  TEST_MODE = !TEST_MODE;
  if (!TEST_MODE) {
    mosaicTiles = new JSONArray();
    mosaicCount = 0;
    flights.clear();
    clearLayer();
    loadMosaic();
  }
  println("Test mode " + (TEST_MODE ? "ON" : "OFF"));
}

// ********************
//   Layout of WALL 1
// ********************

// Boundary k between bands (0 = top edge, MOSAIC_ROWS = bottom edge)
float bandY(int k, float x) {
  Face f = faces[W1];
  if (k <= 0) return 0;
  if (k >= MOSAIC_ROWS) return f.h;
  float bh = f.h / MOSAIC_ROWS;
  return k * bh + waveA * sin(TWO_PI * x / waveL + k * 0.6 + waveP1)
                + 0.3 * waveA * sin(TWO_PI * x / (waveL * 0.43) + k * 1.7 + waveP2);
}

void buildSlots() {
  Face f = faces[W1];
  Random r = new Random(MOSAIC_SEED);
  float bh = f.h / MOSAIC_ROWS;
  waveA  = bh * 0.32;
  waveL  = f.w * rnd(r, 0.3, 0.42);
  waveP1 = rnd(r, 0, TWO_PI);
  waveP2 = rnd(r, 0, TWO_PI);

  // Cell corners of each band along its top (x + slant) and bottom (x - slant) boundary
  FloatList[] topX = new FloatList[MOSAIC_ROWS], botX = new FloatList[MOSAIC_ROWS];
  for (int k = 0; k < MOSAIC_ROWS; k++) {
    topX[k] = new FloatList();
    botX[k] = new FloatList();
    topX[k].append(0);
    botX[k].append(0);
    float x = 0;
    while (true) {
      x += bh * rnd(r, MOSAIC_CELL_MIN, MOSAIC_CELL_MAX);
      if (f.w - x < bh * 0.6) break;
      float sl = rnd(r, -0.3, 0.3) * bh;
      topX[k].append(x + sl);
      botX[k].append(x - sl);
    }
    topX[k].append(f.w);
    botX[k].append(f.w);
  }

  // Each boundary between bands is ONE polyline of straight segments, with a
  // vertex at every corner of the cells above and below, so neighbours share it exactly.
  PVector[][] lines = new PVector[MOSAIC_ROWS + 1][];
  for (int k = 0; k <= MOSAIC_ROWS; k++) {
    FloatList xs = new FloatList();
    if (k > 0)           xs.append(botX[k - 1]);
    if (k < MOSAIC_ROWS) xs.append(topX[k]);
    xs.sort();
    FloatList clean = new FloatList();
    for (float x : xs) if (clean.size() == 0 || x - clean.get(clean.size() - 1) > 1) clean.append(x);
    lines[k] = new PVector[clean.size()];
    for (int i = 0; i < clean.size(); i++) lines[k][i] = new PVector(clean.get(i), bandY(k, clean.get(i)));
  }

  for (int k = 0; k < MOSAIC_ROWS; k++) {
    for (int i = 0; i < topX[k].size() - 1; i++) {
      ArrayList<PVector> top = sliceAt(lines[k],     topX[k].get(i), topX[k].get(i + 1));
      ArrayList<PVector> bot = sliceAt(lines[k + 1], botX[k].get(i), botX[k].get(i + 1));
      slots.add(new Patch(top.toArray(new PVector[0]), bot.toArray(new PVector[0])));
      slotBands.append(k);
    }
  }

  // Fill order: from the centre of the wall outwards
  final float[] key = new float[slots.size()];
  Integer[] idx = new Integer[slots.size()];
  for (int i = 0; i < slots.size(); i++) {
    PVector c = slots.get(i).center();
    key[i] = sq(c.x - f.w / 2) + sq((c.y - f.h / 2) * 2.5) + rnd(r, 0, 1.5) * sq(bh);
    idx[i] = i;
  }
  java.util.Arrays.sort(idx, (a, b) -> Float.compare(key[a], key[b]));
  slotOrder = new int[idx.length];
  for (int i = 0; i < idx.length; i++) slotOrder[i] = idx[i];
}

// ********************
//   Tiles
// ********************

TrencadisTile tileFor(JSONObject rec, int n) {
  int slot = slotOrder[n % slots.size()];
  return makeWordTile(rec, slots.get(slot), slotBands.get(slot));
}

TrencadisTile makeWordTile(JSONObject rec, Patch patch, int band) {
  String word = rec.getString("word", "");
  String hex  = rec.getString("color_hex", "#FFA500");
  int em = rec.getInt("emotion", 4),     wc  = rec.getInt("word_class", 1);
  int ab = rec.getInt("abstraction", 4), ag  = rec.getInt("agency", 4);
  int og = rec.getInt("organic", 4),     ph  = rec.getInt("phenomena_class", 1);
  int tm = rec.getInt("time_duration", 4);
  long seed = wordSeed(word + hex, em, wc, ab, ag, og, ph, tm);
  return new TrencadisTile(seed, parseHexColor(hex), ab, og, ph, wc, patch, band);
}

void stampTile(TrencadisTile tile) {
  mosaicLayer.beginDraw();
  mosaicLayer.colorMode(HSB, 360, 100, 100, 100);
  mosaicLayer.pushMatrix();
  mosaicLayer.scale(RENDER_SCALE);
  mosaicLayer.translate(tile.origin.x, tile.origin.y);
  tile.drawFlat(mosaicLayer, 100, true);   // set in the wall: grout behind the shards
  mosaicLayer.popMatrix();
  mosaicLayer.endDraw();
}

void clearLayer() {
  mosaicLayer.beginDraw();
  mosaicLayer.background(0);
  mosaicLayer.endDraw();
}

// ********************
//   Persistence
// ********************

void loadMosaic() {
  File file = new File(dataPath(MOSAIC_FILE));
  if (!MOSAIC_SAVE || !file.exists()) return;
  try {
    JSONObject o = loadJSONObject(file);
    JSONArray a = o.getJSONArray("tiles");
    for (int i = 0; i < a.size(); i++) {
      JSONObject rec = a.getJSONObject(i);
      stampTile(tileFor(rec, rec.getInt("n", i)));
      mosaicTiles.append(rec);
    }
    mosaicCount = o.getInt("count", a.size());
  } catch (Exception e) {
    println("Could not load " + MOSAIC_FILE + ": " + e.getMessage());
  }
}

void saveMosaic() {
  if (!MOSAIC_SAVE || TEST_MODE) return;
  // Only the tiles still visible (older ones were covered when the wall wrapped)
  JSONArray keep = new JSONArray();
  for (int i = 0; i < mosaicTiles.size(); i++) {
    JSONObject rec = mosaicTiles.getJSONObject(i);
    if (rec.getInt("n", 0) >= mosaicCount - slots.size()) keep.append(rec);
  }
  mosaicTiles = keep;
  JSONObject o = new JSONObject();
  o.setInt("count", mosaicCount);
  o.setJSONArray("tiles", mosaicTiles);
  saveJSONObject(o, dataPath(MOSAIC_FILE));
}

// ********************
//   The ring of walls
// ********************
// The four walls unroll into one long band, as if walking round the room.
// c is the position along it, following each wall's u (left → right as seen
// from inside): WALL 1, WALL 2, WALL 3, WALL 4 and back to WALL 1.
// v is the height measured from the top, the same on every wall.

float ringLength() { return 2 * (ROOM_D + ROOM_W); }

PVector ringPoint(float c, float v) {
  float L = ringLength();
  c = ((c % L) + L) % L;
  float z = WALL_H - v;
  if (c < ROOM_D)              return new PVector(0, ROOM_D - c, z);                 // WALL 1
  c -= ROOM_D;
  if (c < ROOM_W)              return new PVector(c, 0, z);                          // WALL 2
  c -= ROOM_W;
  if (c < ROOM_D)              return new PVector(ROOM_W, c, z);                     // WALL 3
  c -= ROOM_D;
  return new PVector(ROOM_W - c, ROOM_D, z);                                         // WALL 4
}

int ringFace(float c) {
  float L = ringLength();
  c = ((c % L) + L) % L;
  if (c < ROOM_D)              return W1;
  if (c < ROOM_D + ROOM_W)     return W2;
  if (c < 2 * ROOM_D + ROOM_W) return W3;
  return W4;
}

// ********************
//   A tile on its way
// ********************

// ********************
//   The W1 – FLOOR – W3 strip (route across the floor)
// ********************
// WALL 1, FLOOR and WALL 3 unfold into one flat strip. s runs along it:
// 0 = top of WALL 1, WALL_H = WALL 1 meets the floor, WALL_H + ROOM_W = floor
// meets WALL 3, then up to the top of WALL 3. y is the room's Y.

PVector stripPoint(float s, float y) {
  if (s < WALL_H)           return new PVector(0, y, WALL_H - s);
  if (s <= WALL_H + ROOM_W) return new PVector(s - WALL_H, y, 0);
  return new PVector(ROOM_W, y, s - WALL_H - ROOM_W);
}

PVector stripAlong(float s) {   // 3D direction of growing s
  if (s < WALL_H)           return new PVector(0, 0, -1);
  if (s <= WALL_H + ROOM_W) return new PVector(1, 0, 0);
  return new PVector(0, 0, 1);
}

int stripFace(float s) {
  if (s < WALL_H)           return W1;
  if (s <= WALL_H + ROOM_W) return FLOOR;
  return W3;
}

// ********************
//   A tile on its way
// ********************
// When it leaves WALL 3 the tile comes apart: every piece travels on its own,
// leaving in turn, scattering into a loose cloud, turning a little, and they all
// close up again in the slot on WALL 1. The EMOTION decides how the cloud splits
// between routes: love and sadness keep together (one route), joy and surprise
// split in two, anger, fear and disgust in three — round by WALL 2, round by
// WALL 4 or across the FLOOR.

final int ROUTE_W2 = 0, ROUTE_W4 = 1, ROUTE_FLOOR = 2;

int fragmentsFor(int emotion) {
  if (!HAS_FLOOR) return (emotion == 4 || emotion == 6) ? 1 : 2;   // only the two side walls
  switch (emotion) {
    case 4: case 6: return 1;    // love, sadness
    case 2: case 7: return 2;    // surprise, joy
    default:        return 3;    // anger, fear, disgust
  }
}

class Fragment {
  IntList idx = new IntList();   // pieces of the tile
  float ox, oy, rad;             // centre (tile-local) and radius
  float dx, dy;                  // where it scatters to, away from its place (tile units)
  float spin;                    // how much it turns on itself on the way
  int   route;
  float delay, dur;              // frames
  float meanderA, meanderF, meanderP;
  int   turnDir;                 // turning direction when crossing the floor
  float p, scale;                // progress 0..1, current scale
  PVector pos, up;
  int   face;
  // 3D travel: a curve through the air of the room
  PVector a0, a1, a2, a3;        // start on WALL 3, two control points inside the room, end on WALL 1
  PVector sc3;                   // where it scatters to (room units)
  PVector w;                     // current position in the room
  float theta, tumble;           // turn round (WALL 3 → WALL 1) and tumbling on the way
}

class TileFlight {
  TrencadisTile tile;
  int   state = FLIGHT_HOLD;
  float age = 0, assembly = 0;
  float assembleT, holdT, travelT;
  float holdScale;
  float rotX, rotY, rotX0, rotY0;   // 3D sway on the main wall
  float hu, hv;                     // hold position on WALL 3 (local u, v)
  ArrayList<Fragment> frags = new ArrayList<Fragment>();
  boolean landed = false;

  TileFlight(TrencadisTile tile, JSONObject rec) {
    this.tile = tile;
    Random r = new Random(tile.seed * 31 + 7);
    int agency  = rec.getInt("agency", 4);
    int organic = rec.getInt("organic", 4);
    int time    = rec.getInt("time_duration", 4);
    int emotion = rec.getInt("emotion", 4);
    assembleT = map(agency, 1, 7, ASSEMBLE_FRAMES_MAX, ASSEMBLE_FRAMES_MIN);   // energetic words assemble fast...
    travelT   = map(agency, 1, 7, 760, 360);   // ...and travel fast
    holdT     = map(time,   1, 7, HOLD_FRAMES_MIN, HOLD_FRAMES_MAX);           // long-lasting words stay longer on the main wall

    Face m = faces[W3];
    holdScale = min(m.h * HOLD_HEIGHT / tile.tileH, m.w * 0.4 / tile.tileW);
    hu = m.w / 2;
    hv = m.h * HOLD_Y;   // above the text input
    makeFragments(r, fragmentsFor(emotion), organic);
  }

  // ── Breaking into fragments and choosing their routes ──

  void makeFragments(Random r, int k, int organic) {
    int[] routes;
    float cutAng;   // direction of the cut between fragments
    if (k == 1) {
      int[] one = { ROUTE_W2, ROUTE_W4, ROUTE_FLOOR };
      routes = new int[] { one[r.nextInt(HAS_FLOOR ? 3 : 2)] };
      cutAng = 0;
    } else if (k == 2) {
      if (r.nextFloat() < 0.7 || !HAS_FLOOR) { routes = new int[] { ROUTE_W2, ROUTE_W4 }; cutAng = rnd(r, -0.5, 0.5); }  // left | right
      else { routes = new int[] { r.nextBoolean() ? ROUTE_W2 : ROUTE_W4, ROUTE_FLOOR }; cutAng = HALF_PI + rnd(r, -0.5, 0.5); }  // top | bottom
    } else {
      routes = new int[] { ROUTE_W2, ROUTE_W4, ROUTE_FLOOR };
      cutAng = rnd(r, 0, TWO_PI);
    }

    for (int i = 0; i < k; i++) frags.add(new Fragment());
    for (int i = 0; i < tile.pieces.size(); i++) {
      Piece p = tile.pieces.get(i);
      int g;
      if (k == 1)      g = 0;
      else if (k == 2) g = (p.cx * cos(cutAng) + p.cy * sin(cutAng) < 0) ? 0 : 1;
      else             g = (int) (((atan2(p.cy, p.cx) - cutAng) % TWO_PI + TWO_PI) % TWO_PI / (TWO_PI / 3)) % 3;
      frags.get(g).idx.append(i);
    }
    for (int i = frags.size() - 1; i >= 0; i--) if (frags.get(i).idx.size() == 0) frags.remove(i);
    for (Fragment f : frags) {
      for (int i : f.idx) { f.ox += tile.pieces.get(i).cx / f.idx.size(); f.oy += tile.pieces.get(i).cy / f.idx.size(); }
      for (int i : f.idx) {
        Piece p = tile.pieces.get(i);
        for (int j = 0; j < p.x.length; j++) f.rad = max(f.rad, dist(p.x[j], p.y[j], f.ox, f.oy));
      }
      float d = dist(0, 0, f.ox, f.oy);
      f.dx = d > 1 ? f.ox / d : 0;
      f.dy = d > 1 ? f.oy / d : 1;
    }

    // Routes by position: the left part goes round by WALL 2 (WALL 3's left is
    // the WALL 2 side), the right part by WALL 4, the lowest part across the floor
    for (Fragment f : frags) f.turnDir = r.nextBoolean() ? 1 : -1;
    ArrayList<Fragment> left = new ArrayList<Fragment>(frags);
    if (frags.size() == 1) frags.get(0).route = routes[0];
    else {
      boolean hasFloor = false;
      for (int rt : routes) hasFloor |= (rt == ROUTE_FLOOR);
      if (hasFloor) {
        Fragment low = left.get(0);
        for (Fragment f : left) if (f.oy > low.oy) low = f;
        low.route = ROUTE_FLOOR;
        left.remove(low);
      }
      java.util.Collections.sort(left, (a, b) -> Float.compare(a.ox, b.ox));
      if (left.size() == 2) { left.get(0).route = ROUTE_W2; left.get(1).route = ROUTE_W4; }
      else if (left.size() == 1) {
        int wall = ROUTE_W2;
        for (int rt : routes) if (rt != ROUTE_FLOOR) wall = rt;
        left.get(0).route = wall;
      }
    }

    // The whole tile comes apart: every piece travels on its own, on its group's route
    ArrayList<Fragment> groups = frags;
    frags = new ArrayList<Fragment>();
    for (Fragment g : groups) {
      float gx0 = Float.MAX_VALUE, gx1 = -Float.MAX_VALUE, gy1 = -Float.MAX_VALUE;
      for (int i : g.idx) { Piece p = tile.pieces.get(i); gx0 = min(gx0, p.cx); gx1 = max(gx1, p.cx); gy1 = max(gy1, p.cy); }
      for (int i : g.idx) {
        Piece p = tile.pieces.get(i);
        Fragment f = new Fragment();
        f.idx.append(i);
        f.route = g.route;
        f.ox = p.cx;
        f.oy = p.cy;
        for (int j = 0; j < p.x.length; j++) f.rad = max(f.rad, dist(p.x[j], p.y[j], p.cx, p.cy));
        // Scatter: away from the group's centre, opening into a loose cloud
        float a = atan2(p.cy - g.oy, p.cx - g.ox) + rnd(r, -0.9, 0.9);
        float d = tile.radius * rnd(r, 0.3, 1.3) * SCATTER;
        f.dx = cos(a) * d;
        f.dy = sin(a) * d;
        f.spin = rnd(r, -1, 1) * 1.2;
        // Leaves in turn: the pieces nearest to its way out go first
        float order;
        if (g.route == ROUTE_W2)      order = (p.cx - gx0) / max(1, gx1 - gx0);
        else if (g.route == ROUTE_W4) order = (gx1 - p.cx) / max(1, gx1 - gx0);
        else                          order = (gy1 - p.cy) / max(1, tile.tileH);
        f.delay    = (0.3 * order + rnd(r, 0, 0.12)) * travelT;
        f.dur      = (travelT - f.delay) * rnd(r, 0.8, 1.0) * (f.route == ROUTE_FLOOR ? 0.85 : 1);
        f.meanderA = map(organic, 1, 7, 60, 260) * rnd(r, 0.5, 1.2) * (r.nextBoolean() ? 1 : -1);
        f.meanderF = rnd(r, 0.5, 1.5);
        f.meanderP = rnd(r, 0, TWO_PI);
        f.turnDir  = g.turnDir;
        f.scale    = holdScale;
        makePath3D(r, f);
        place(f);
        frags.add(f);
      }
    }
  }

  // The 3D curve of a piece: leaves WALL 3 into the room, flies at its own depth and
  // height (on the WALL 2 side, the WALL 4 side or low over the floor, by route), lands on WALL 1
  void makePath3D(Random r, Fragment f) {
    f.a0 = faces[W3].toRoom(hu + f.ox * holdScale, hv + f.oy * holdScale);
    f.a3 = faces[W1].toRoom(tile.origin.x + f.ox, tile.origin.y + f.oy);
    f.a1 = PVector.add(f.a0, new PVector(-ROOM_W * rnd(r, 0.2, 0.45) * DEPTH_3D, 0, 0));
    f.a2 = PVector.add(f.a3, new PVector( ROOM_W * rnd(r, 0.2, 0.45) * DEPTH_3D, 0, 0));
    // Below the audience's eyes: seen from the centre of the room, anything higher is
    // projected up towards the ceiling (where nothing is shown) and seems to vanish there
    float eyeZ = VIEWER_HEIGHT;
    if (f.route == ROUTE_FLOOR) {
      f.a1.z = eyeZ * rnd(r, 0.08, 0.3);                            // low, skimming the floor
      f.a2.z = eyeZ * rnd(r, 0.08, 0.3);
    } else {
      float side = (f.route == ROUTE_W2 ? -1 : 1) * ROOM_D * rnd(r, 0.15, 0.35);
      f.a1.add(0, side, 0);
      f.a2.add(0, side * rnd(r, 0.6, 1.0), 0);
      // Well below the eyes (close to eye level they would stretch hugely over the floor);
      // with no floor, around eye level instead, so they are seen on the walls
      float lo = HAS_FLOOR ? 0.25 : 0.8, hi = HAS_FLOOR ? 0.6 : 1.15;
      f.a1.z = eyeZ * rnd(r, lo, hi);
      f.a2.z = eyeZ * rnd(r, lo, hi);
    }
    for (PVector q : new PVector[] { f.a1, f.a2 }) {
      q.y = constrain(q.y, ROOM_D * 0.05, ROOM_D * 0.95);
      q.z = constrain(q.z, WALL_H * 0.03, HAS_FLOOR ? VIEWER_HEIGHT * 0.6 : WALL_H * 0.85);
    }
    float a = rnd(r, 0, TWO_PI), b = rnd(r, -1, 1);
    f.sc3 = new PVector(sqrt(1 - b * b) * cos(a), sqrt(1 - b * b) * sin(a), b).mult(tile.radius * SCATTER * rnd(r, 0.4, 1.2));
    f.tumble = rnd(r, -1, 1) * 1.0;
  }

  void depart() {
    state = FLIGHT_TRAVEL;
    age   = 0;
    rotX0 = atan2(sin(rotX), cos(rotX));
    rotY0 = atan2(sin(rotY), cos(rotY));
  }

  void update() {
    age++;
    if (state == FLIGHT_SET) {
      // In its slot on WALL 1: the grout seeps in under the shards and dries
      if (age >= GROUT_SET_FRAMES) {
        stampTile(tile);
        landed = true;
      }
      return;
    }
    if (state == FLIGHT_HOLD) {
      assembly = min(1, age / assembleT);
      sway();
      if (age >= assembleT + holdT) depart();
      return;
    }

    assembly = min(1, assembly + 1.0 / 30);   // if it had to leave early, finish quickly
    float k = 1 - smooth01(age / TILT_FRAMES);
    rotX = rotX0 * k;
    rotY = rotY0 * k;

    // The fragments only start once the tile has straightened up on WALL 3
    float t = age - TILT_FRAMES;
    boolean arrived = true;
    for (Fragment f : frags) {
      f.p = constrain((t - f.delay) / f.dur, 0, 1);
      if (f.p < 1) arrived = false;
      place(f);
    }
    if (arrived) {
      state = FLIGHT_SET;
      age   = 0;
    }
  }

  // Gentle 3D movement while it is shown on the main wall (camera modes)
  void sway() {
    switch (camMode) {
      case 2: rotX = 0; rotY = 0; break;
      case 3: rotY = sin(frameCount * 0.004) * 0.09; rotX = sin(frameCount * 0.003) * 0.04; break;
      case 4: rotY = frameCount * 0.006; rotX = sin(frameCount * 0.003) * 0.08; break;
      case 5: rotY = camRotH; rotX = -camRotV; break;
    }
  }

  // Position of a fragment along its route
  void place(Fragment f) {
    float e = easeInOutCubic(f.p);
    f.scale = lerp(holdScale, 1, easeInOutCubic(f.p / 0.3));
    // The pieces drift apart on the way and close up again at the end
    float apart = pow(max(0, sin(PI * e)), 0.7);   // sin(PI) is a tiny negative number: pow() of it would be NaN
    float lx = f.ox * f.scale + f.dx * apart;       // offset from the tile centre (x right, y down)
    float ly = f.oy * f.scale + f.dy * apart;
    float wave = f.meanderA * sin(PI * e) * (0.6 + 0.4 * sin(TWO_PI * f.meanderF * e + f.meanderP));

    if (TRAVEL_3D) {
      // Through the air: along its curve, scattered on the way, turning round to face WALL 1
      f.w = new PVector(bezierPoint(f.a0.x, f.a1.x, f.a2.x, f.a3.x, e),
                        bezierPoint(f.a0.y, f.a1.y, f.a2.y, f.a3.y, e),
                        bezierPoint(f.a0.z, f.a1.z, f.a2.z, f.a3.z, e));
      f.w.add(PVector.mult(f.sc3, apart));
      f.w.x = constrain(f.w.x, 0, ROOM_W);
      f.w.y = constrain(f.w.y, 0, ROOM_D);
      f.w.z = constrain(f.w.z, 0, WALL_H);   // (only the ends, on WALL 3 / WALL 1, are above the eyes)
      f.theta = f.turnDir * PI * smooth01(e);
    }
    if (f.route == ROUTE_FLOOR) {
      // Down WALL 3, across the floor turning round half a circle, up WALL 1
      float s0 = 2 * WALL_H + ROOM_W - hv, y0 = hu;
      float s1 = tile.origin.y,            y1 = ROOM_D - tile.origin.x;
      float s = lerp(s0, s1, e), y = lerp(y0, y1, e) + wave;
      float th = f.turnDir * PI * smooth01(constrain((WALL_H + ROOM_W - s) / ROOM_W, 0, 1));
      float ux = cos(th), uy = sin(th);            // tile "up" in the strip (s, y)
      s += lx * -uy - ly * ux;                     // local x → (-uy, ux), local y (down) → -up
      y += lx *  ux - ly * uy;
      f.pos  = stripPoint(s, y);
      f.up   = PVector.add(PVector.mult(stripAlong(s), ux), new PVector(0, uy, 0));
      f.face = stripFace(s);
    } else {
      // Round the walls, always upright
      float c0 = ROOM_D + ROOM_W + hu;
      float c1 = tile.origin.x + (f.route == ROUTE_W4 ? ringLength() : 0);
      float c  = lerp(c0, c1, e) + lx;
      float v  = lerp(hv, tile.origin.y, e) + wave + ly;
      float m  = f.rad * f.scale;   // keep it between floor and ceiling while travelling
      float vs = hv + f.oy * holdScale, ve = tile.origin.y + f.oy;
      v = constrain(v, min(m, min(vs, ve)), max(WALL_H - m, max(vs, ve)));
      f.pos  = ringPoint(c, v);
      f.up   = new PVector(0, 0, 1);
      f.face = ringFace(c);
    }
  }

  // Still on the main wall in 3D (assembling, swaying or straightening up)
  boolean onMainWall() {
    return state == FLIGHT_HOLD || (state == FLIGHT_TRAVEL && (assembly < 1 || age < TILT_FRAMES));
  }

  // On WALL 3 with the wallCamera (Room.pde)
  void displayMain(PGraphics pg, Face f) {
    if (!onMainWall()) return;
    float z0 = (f.h / 2) / tan(PI / 6);
    pg.push();
    pg.translate(hu, hv, 0);
    pg.rotateY(rotY);
    pg.rotateX(rotX);
    pg.scale(holdScale);
    tile.drawAssembling(pg, 100, assembly, z0 * ASSEMBLE_DEPTH / holdScale);
    pg.pop();
  }

  // 3D travel: the pieces in the air of the room, with the viewerCamera (Room.pde)
  void display3D(PGraphics pg) {
    if (state != FLIGHT_TRAVEL || onMainWall()) return;
    for (Fragment fr : frags) {
      pg.pushMatrix();
      pg.translate(fr.w.x, fr.w.y, fr.w.z);
      pg.rotateZ(fr.theta);
      // WALL 3's frame: tile x → room +Y, tile y (down) → room −Z, facing into the room
      pg.applyMatrix(0, 0, -1, 0,
                     1, 0,  0, 0,
                     0, -1, 0, 0,
                     0, 0,  0, 1);
      pg.rotateY(fr.tumble * sin(PI * easeInOutCubic(fr.p)));
      pg.rotate(fr.spin * sin(PI * easeInOutCubic(fr.p)));
      pg.scale(fr.scale);
      tile.drawPieces(pg, 100, fr.idx, fr.ox, fr.oy);
      pg.popMatrix();
    }
  }

  // Flat on any surface, continuing across the seams
  void displayFlat(PGraphics pg, Face target) {
    if (onMainWall()) return;
    if (TRAVEL_3D && state == FLIGHT_TRAVEL) return;   // drawn by display3D
    if (state == FLIGHT_SET) {
      // Whole again, in its slot
      if (target.id != W1) return;
      pg.push();
      pg.translate(tile.origin.x, tile.origin.y);
      tile.drawSetting(pg, 100, age / GROUT_SET_FRAMES);
      pg.pop();
      return;
    }
    for (Fragment fr : frags) {
      Face src = faces[fr.face];
      PVector p = target.localPoint(fr.pos, src);
      if (p == null) continue;
      float reach = fr.rad * fr.scale + 20;
      if (p.x < -reach || p.x > target.w + reach || p.y < -reach || p.y > target.h + reach) continue;
      PVector u = target.localDir(fr.up, src);
      pg.push();
      pg.translate(p.x, p.y);
      pg.rotate(atan2(u.y, u.x) + HALF_PI);
      pg.scale(fr.scale);
      pg.rotate(fr.spin * sin(PI * easeInOutCubic(fr.p)));   // turns on itself, back in place at the end
      tile.drawPieces(pg, 100, fr.idx, fr.ox, fr.oy);
      pg.pop();
    }
  }
}
