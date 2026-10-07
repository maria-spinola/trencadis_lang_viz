// ═══════════════════════════════════════════════════════════
/* WordsSystem.pde
* Word from input.json → trencadís tile that travels to WALL 1 (Mosaic.pde)
* PoemWord             → small trencadís tiles floating across walls + floor, from poem_words.json
*/
// ═══════════════════════════════════════════════════════════

JSONArray poemWords;
int poemWordCursor = 0;
int poemSpawnTimer = 0;

ArrayList<PoemWord> poemWordsList = new ArrayList<>();

// ── Setup ──────────────────────────────────────────────────

void setupWords() {
  try {
    JSONObject poem = loadJSONObject("poem_words.json");
    poemWords = poem.getJSONArray("words");
    println("Loaded " + poemWords.size() + " poem words");
  } catch (Exception e) {
    println("Could not load poem_words.json: " + e.getMessage());
    poemWords = new JSONArray();
  }
}

JSONObject nextPoemWord() {
  if (poemWords == null || poemWords.size() == 0) return null;
  int wi = poemWordCursor % poemWords.size();
  poemWordCursor++;
  return poemWords.getJSONObject(wi);
}

// ********************
//   Update + Display
// ********************

void updateWords() {
  if (!SHOW_POEM) {            // poem off: no tiles spawned, the ones floating disappear
    poemWordsList.clear();
    return;
  }
  // Spawn poem words on timer
  poemSpawnTimer++;
  if (poemSpawnTimer >= POEM_SPAWN_INTERVAL) {
    poemSpawnTimer = 0;
    if (poemWordsList.size() < MAX_POEM_WORDS) {
      int n = poemWordCursor;
      JSONObject wordObj = nextPoemWord();
      if (wordObj != null) poemWordsList.add(new PoemWord(wordObj, n));
    }
  }

  for (int i = poemWordsList.size()-1; i >= 0; i--) {
    poemWordsList.get(i).update();
    if (poemWordsList.get(i).isDead()) poemWordsList.remove(i);
  }
}

// Drawing happens per surface in renderFaces() (Room.pde)

// *****************
//    POEM WORDS
// *****************

class PoemWord {
  int face;           // surface the tile is on (index in faces[])
  PVector pos;        // 3D room position, always on that surface
  PVector vel;        // 3D velocity, tangent to the surface
  PVector up;         // 3D "up" of the tile, tangent to the surface
  float age, lifetime, seed;
  float alpha, life;

  TrencadisTile tile;

  // n = how many poem words were spawned before → same sequence on every run
  PoemWord(JSONObject wordObj, int n) {
    Random r = new Random(MOSAIC_SEED * 7919 + n);

    // Spot anywhere in the room (more area = more tiles)
    face = randomFaceByArea(r);
    Face f = faces[face];
    float vMin = (face == FLOOR) ? 0 : CEILING_MARGIN;
    float vMax = (face == FLOOR || HAS_FLOOR) ? f.h : f.h - CEILING_MARGIN;
    pos = f.toRoom(rnd(r, 0, f.w), rnd(r, vMin, vMax));

    float dir   = rnd(r, 0, TWO_PI);
    float speed = rnd(r, FLOAT_SPEED_MIN, FLOAT_SPEED_MAX);
    vel = PVector.add(PVector.mult(f.eU, cos(dir) * speed), PVector.mult(f.eV, sin(dir) * speed));
    up  = PVector.mult(f.eV, -1);

    age      = 0;
    lifetime = rnd(r, FLOAT_LIFE_MIN, FLOAT_LIFE_MAX);
    seed     = rnd(r, 0, 1000);
    alpha    = 0;
    life     = 0;

    String word    = wordObj.getString("word", "");
    String hex     = wordObj.getString("color_hex", "#FFFFFF");
    int emotion    = constrain(wordObj.getInt("emotion",         4), 1, 7);
    int wordClass  = constrain(wordObj.getInt("word_class",      1), 1, 8);
    int phenomenon = constrain(wordObj.getInt("phenomena_class", 1), 1, 7);
    int bAbstract  = constrain(wordObj.getInt("abstraction",     4), 1, 7);
    int bAgency    = constrain(wordObj.getInt("agency",          4), 1, 7);
    int bOrganic   = constrain(wordObj.getInt("organic",         4), 1, 7);
    int bTime      = constrain(wordObj.getInt("time_duration",   4), 1, 7);

    // Built around (0,0): position and rotation are applied per surface in display()
    long tseed = wordSeed(word + hex, emotion, wordClass, bAbstract, bAgency, bOrganic, phenomenon, bTime);
    Patch shape = freePatch(new Random(tseed), POEM_TILE_SIZE, POEM_TILE_SIZE * 0.8);
    tile = new TrencadisTile(tseed, parseHexColor(hex), bAbstract, bOrganic, phenomenon, wordClass, shape, -1);
  }

  void update() {
    age++;
    float p = age / lifetime;

    // Alpha -> fade in at birth, fade out at the end
    alpha = constrain(min(p / 0.2, (1 - p) / 0.25), 0, 1) * POEM_ALPHA;
    // Life -> the tile grows during the first part of its life
    life  = constrain(map(p, 0, 0.6, 0.15, 1), 0.15, 1);

    move();
  }

  void move() {
    Face f = faces[face];

    // Gentle wandering: turn the velocity inside the surface plane
    float turn = (noise(seed, age * 0.004) - 0.5) * 0.05;
    PVector side = f.n.cross(vel);
    vel = PVector.add(PVector.mult(vel, cos(turn)), PVector.mult(side, sin(turn)));

    if (face != FLOOR) {
      // On walls, slowly turn upright again
      PVector wallUp = PVector.mult(f.eV, -1);
      up.lerp(wallUp, 0.005);
      if (up.mag() < 0.01) up = wallUp;
      up.normalize();

      // Turn back before reaching the ceiling (nothing is projected there)
      float v = PVector.sub(pos, f.O).dot(f.eV);
      float s = vel.dot(f.eV);
      if (v < CEILING_MARGIN && s < 0) vel.add(PVector.mult(f.eV, -2 * s));
      // No floor in this venue: turn back before the bottom edge too
      if (!HAS_FLOOR && v > f.h - CEILING_MARGIN && s > 0) vel.add(PVector.mult(f.eV, -2 * s));
    }

    pos.add(vel);
    int next = foldOver(face, pos, vel, up);   // Room.pde — crosses to the next surface
    if (next >= 0) face = next;
  }

  void display(PGraphics pg, Face target) {
    if (alpha < 1) return;
    Face src = faces[face];
    PVector p = target.localPoint(pos, src);
    if (p == null) return;
    float reach = tile.radius * life + 20;
    if (p.x < -reach || p.x > target.w + reach || p.y < -reach || p.y > target.h + reach) return;

    PVector u = target.localDir(up, src);
    pg.push();
    pg.translate(p.x, p.y);
    pg.rotate(atan2(u.y, u.x) + HALF_PI);
    pg.scale(life);
    tile.drawFlat(pg, alpha);
    pg.pop();
  }

  boolean isDead() {
    return age >= lifetime;
  }
}
