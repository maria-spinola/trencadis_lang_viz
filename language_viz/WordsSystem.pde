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
ArrayList<PoemWord> poemByDepth = new ArrayList<>();   // drawing order, far first (Room.pde)

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
  // A new poem word now and then; when there are too many, the oldest little shard fades away
  poemSpawnTimer++;
  if (poemSpawnTimer >= POEM_SPAWN_INTERVAL) {
    poemSpawnTimer = 0;
    // Too many little shards: the oldest one fades away (its word stays on the floor)
    int shards = 0, words = 0;
    for (PoemWord pw : poemWordsList) { if (!pw.leaving) shards++; if (!pw.wordLeaving) words++; }
    if (shards >= MAX_POEM_WORDS) {
      for (PoemWord pw : poemWordsList) if (!pw.leaving) { pw.leave(); break; }
    }
    // Only with very many words on the floor does the oldest word fade
    if (words >= MAX_FLOOR_WORDS) {
      for (PoemWord pw : poemWordsList) if (!pw.wordLeaving) { pw.wordLeave(); break; }
    }
    int n = poemWordCursor;
    JSONObject wordObj = nextPoemWord();
    if (wordObj != null) poemWordsList.add(new PoemWord(wordObj, n));
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

// The poem tiles live on a strip that goes round the walls (Mosaic.pde: ring
// coordinates c along, v from the top). They never enter the mural wall (WALL 1 / BACK)
// nor the middle of the main wall (where the tile assembles and the text box is):
// that leaves two free stretches, A (WALL 2 + left of WALL 3) and B (right of WALL 3 + WALL 4).
float poemReach()  { return POEM_TILE_SIZE * (0.75 + POEM_SPREAD); }   // how far a cloud of pieces reaches

// No-floor venue: the words float along the low band of WALL 4, WALL 1 and WALL 2, never on the main wall
float[] bandStretch() {
  float m = POEM_TILE_SIZE * 0.6;
  return new float[] { 2 * ROOM_D + ROOM_W + m, 2 * ROOM_D + 2 * ROOM_W + ROOM_D + ROOM_W - m };
}

PFont poemFont;

// Life of a poem word:
//   JOURNEY  out of the depth behind the main wall (where typed words appear), tiny and dark,
//            already heading for its spot along the walls, opening more and more on the way;
//            each piece runs ahead and falls behind the group
//   WORD     the cloud stops; the word appears on black in the empty middle and stays 2 s;
//            then the WORD leaves: it glides down the wall and floats on the floor
//            (no floor in the venue: along the low band of the walls)
//   CLOSE    meanwhile the pieces close up into the tile
//   COLLAPSE the word fades and all the pieces fold into one small shard
//   MINI     the little shard wanders all the walls, behind the mural and the text window.
//            Only when there are very many does the oldest (word and shard) fade away.
class PoemWord {
  String word;
  int   stretch;              // 0 = A, 1 = B
  float c, v;                 // centre on the ring of walls
  float c0, v0, c1, v1;       // start (main wall) and destination
  float vc, vPhase, vAmp;     // drift of the little shard
  float bandV;                // no-floor venue: how far above the bottom edge it floats
  float age, seed;
  float tE, tT, tC, tW, tX;   // phase lengths (frames)
  float[] sx, sy, spin;       // per piece: where it drifts to when open, how much it turns
  float[] lag, oscF, oscP;    // per piece: place in the travelling group, back-and-forth rhythm
  float[] goT;                // per piece: when it fades away while the tile shrinks (0..1)
  PVector pos, vel, up;       // the little shard wandering the walls (MINI)
  int face;
  float wc, wv;               // the written word: on the ring of walls while it goes down…
  PVector wpos, wvel, wup;    // …then floating on the floor
  float wordStart;            // age at which the word leaves the tile and goes down
  float wdir = 1;             // no-floor venue: direction along the low band
  float depth;                // 0 = near … 1 = far: smaller, dimmer, more transparent and slower
  float depS, dimK, alphaK, spdK;
  float depth0, pace, sizeK;  // its own resting depth, pace and size
  PVector wtarget;            // where the word is drifting to on the floor
  int wlegs = 0;
  int   miniIdx;              // the piece that stays as the little shard
  float miniScale, miniSpin;
  boolean leaving = false;
  float leaveAge;

  // state of this frame
  float alpha, apart, scl, dim, wordA, gather, pieceS;

  TrencadisTile tile;

  // n = how many poem words were spawned before → same sequence on every run
  PoemWord(JSONObject wordObj, int n) {
    Random r = new Random(MOSAIC_SEED * 7919 + n);
    if (poemFont == null) poemFont = createFont("Georgia", 96);

    // Starts behind the middle of the main wall, at the height of the assembling tile
    c0 = ROOM_D + ROOM_W + ROOM_D / 2;
    v0 = WALL_H * HOLD_Y;
    // Its depth: near words are big and bright, far ones small, dim and slow (sense of 3D)
    Random rd = new Random(MOSAIC_SEED * 31 + n);
    depth0 = rd.nextFloat();
    pace   = rnd(rd, 0.5, 1.7);   // some are quick, others slow
    sizeK  = rnd(rd, POEM_SIZE_MIN, POEM_SIZE_MAX);   // and some simply bigger than others
    setDepth(depth0);
    // Goes anywhere on a side wall — high, low, centred, in a corner — where its cloud
    // overlaps least with the clouds still open
    float best = -1;
    for (int k = 0; k < 80; k++) {
      int st = rd.nextInt(2);
      // only the part of the wall the mural hasn't reached yet (it grows from the back corner)
      float gap = POEM_TILE_SIZE * 0.3 + footprint() * 0.55;   // the whole open cloud clear of the mural
      float cov2 = MOSAIC_SIDES ? sideCovered(W2) + gap : 0, cov4 = MOSAIC_SIDES ? sideCovered(W4) + gap : 0;
      if (st == 0 && cov2 > ROOM_W - footprint()) st = 1;
      if (st == 1 && cov4 > ROOM_W - footprint()) st = 0;
      float w0 = (st == 0) ? ROOM_D : 2 * ROOM_D + ROOM_W, w1 = w0 + ROOM_W;   // WALL 2 or WALL 4
      if (st == 0) w0 += min(cov2, ROOM_W - footprint()); else w1 -= min(cov4, ROOM_W - footprint());
      float hw = footprint() * 0.45, hv = vfootprint() * 0.6;   // may lean over a corner a little
      float cc = rnd(rd, w0 + hw, max(w0 + hw, w1 - hw));
      float vv = rnd(rd, min(hv, WALL_H / 2), max(WALL_H / 2, WALL_H - hv));
      float score = Float.MAX_VALUE;
      for (PoemWord o : poemWordsList) {
        if (o.gather >= 1 || o.leaving) continue;          // already a little shard: no cloud there
        float dx = (cc - o.c1) / (footprint() + o.footprint()), dy = (vv - o.v1) / (vfootprint() + o.vfootprint());
        score = min(score, sqrt(dx * dx + dy * dy));
      }
      if (score > best) { best = score; stretch = st; c1 = cc; v1 = vv; }
      if (score >= 0.9) break;   // the first random spot that doesn't overlap: centre, corner, high, low…
    }
    r.nextFloat(); r.nextFloat(); r.nextFloat();   // (keeps the rest of the random sequence)
    c = c0;
    v = v0;
    vc      = rnd(r, 0.4, 1.0) * (r.nextBoolean() ? 1 : -1);   // (direction kept for the random sequence)
    wdir    = (vc > 0) ? -1 : 1;
    vPhase  = rnd(r, 0, TWO_PI);
    vAmp    = rnd(r, 0.04, 0.1) * WALL_H;
    seed    = rnd(r, 0, 1000);
    bandV   = rnd(r, 0.08, 0.2) * WALL_H;
    tE = POEM_EMERGE_FRAMES; tT = POEM_TRAVEL_FRAMES; tC = POEM_CLOSE_FRAMES; tW = 30 + POEM_WORD_FRAMES;
    wordStart = tE + tT + tW; tX = POEM_COLLAPSE_FRAMES;

    word           = wordObj.getString("word", "");
    String hex     = wordObj.getString("color_hex", "#FFFFFF");
    int emotion    = constrain(wordObj.getInt("emotion",         4), 1, 7);
    int wordClass  = constrain(wordObj.getInt("word_class",      1), 1, 8);
    int phenomenon = constrain(wordObj.getInt("phenomena_class", 1), 1, 7);
    int bAbstract  = constrain(wordObj.getInt("abstraction",     4), 1, 7);
    int bAgency    = constrain(wordObj.getInt("agency",          4), 1, 7);
    int bOrganic   = constrain(wordObj.getInt("organic",         4), 1, 7);
    int bTime      = constrain(wordObj.getInt("time_duration",   4), 1, 7);

    // Built around (0,0): position is applied per surface in display()
    long tseed = wordSeed(word + hex, emotion, wordClass, bAbstract, bAgency, bOrganic, phenomenon, bTime);
    Patch shape = freePatch(new Random(tseed), POEM_TILE_SIZE, POEM_TILE_SIZE * 0.8);
    tile = new TrencadisTile(tseed, parseHexColor(hex), bAbstract, bOrganic, phenomenon, wordClass, shape, -1);

    // Where each piece drifts to when open: away from the centre, wider than tall (walls are low)
    int np = tile.pieces.size();
    sx = new float[np]; sy = new float[np]; spin = new float[np];
    lag = new float[np]; oscF = new float[np]; oscP = new float[np];
    float bestA = -1;
    for (int i = 0; i < np; i++) {
      Piece p = tile.pieces.get(i);
      float a = atan2(p.cy, p.cx) + rnd(r, -0.7, 0.7);
      float d = POEM_TILE_SIZE * POEM_SPREAD * rnd(r, 0.3, 1.0);
      sx[i] = cos(a) * d;
      sy[i] = sin(a) * d * 0.55;
      spin[i] = rnd(r, -1, 1) * 1.2;
      lag[i]  = rnd(r, -1, 1);
      oscF[i] = rnd(r, 0.008, 0.02);
      oscP[i] = rnd(r, 0, TWO_PI);
      // the little shard: a fair-sized piece near the middle
      float per = 0;
      for (int j = 0; j < p.x.length; j++) { int j2 = (j + 1) % p.x.length; per += dist(p.x[j], p.y[j], p.x[j2], p.y[j2]); }
      float chunk = p.area / max(1, per * per);   // 0.077 square … ~0.02 splinter
      float score = p.area * sq(chunk / 0.07) / (1 + dist(p.cx, p.cy, 0, 0) / (POEM_TILE_SIZE * 0.15));
      if (score > bestA) { bestA = score; miniIdx = i; }
    }
    miniScale = (np > 0) ? min(1, POEM_MINI_SIZE / max(1, sqrt(tile.pieces.get(miniIdx).area))) : 1;   // only ever shrinks
    goT = new float[np];
    if (np > 0) {
      Piece keep = tile.pieces.get(miniIdx);
      float dmax = 1;
      for (Piece p : tile.pieces) dmax = max(dmax, dist(p.cx, p.cy, keep.cx, keep.cy));
      for (int i = 0; i < np; i++) {
        Piece p = tile.pieces.get(i);
        goT[i] = 0.55 * (1 - dist(p.cx, p.cy, keep.cx, keep.cy) / dmax) + rnd(r, 0, 0.15);   // the furthest go first
      }
    }
    miniSpin  = rnd(r, -1, 1) * 0.004;
  }

  void leave() { leaving = true; leaveAge = age; }   // the little shard fades; the word stays
  boolean shrunk = false;
  boolean wordLeaving = false;
  float wordLeaveAge, wordAlpha;
  void wordLeave() { wordLeaving = true; wordLeaveAge = age; }

  void setDepth(float d) {
    depth  = constrain(d, 0, 1);
    depS   = lerp(1.0, POEM_FAR_SCALE, depth) * sizeK;
    dimK   = lerp(1.0, 0.55, depth);
    alphaK = 1;                     // no transparency with depth: smaller and dimmer only
    spdK   = lerp(1.0, 0.55, depth);
  }

  // Half-width of its open cloud on the wall
  float footprint()  { return POEM_TILE_SIZE * (0.55 + POEM_SPREAD * 0.8) * depS; }   // half-width of its open cloud
  float vfootprint() { return POEM_TILE_SIZE * (0.45 + POEM_SPREAD * 0.45) * depS; }  // half-height

  float travel;   // 0..1 how far along the journey (for the group stretching along the way)

  void update() {
    age++;
    float t = age;
    gather = 0; wordA = 0; scl = 1; dim = 1; apart = 0; travel = 0; pieceS = 1;
    float fade = 1;
    float tJ = tE + tT;
    if (t < tJ) {                                  // JOURNEY: out of the depth, already on its way
      float e = easeInOutCubic(t / tJ);
      float d = smooth01(t / tE);                  // coming out of the depth during the first part
      scl = 1 / (1 + POEM_EMERGE_DEPTH * (1 - d));
      dim = lerp(0.1, 1, d);
      fade = smooth01(t / (tE * 0.25));
      apart = lerp(0.2, 1, smooth01(t / tJ));      // keeps opening along the way
      pieceS = lerp(POEM_BIRTH_SCALE, 1, smooth01((t / tJ - POEM_GROW_START) / (1 - POEM_GROW_START)));   // small while moving away, then they grow
      travel = sin(PI * e);                        // stretched out while moving, gathered at the ends
      c = lerp(c0, c1, e);
      v = lerp(v0, v1, e) + sin(PI * e) * vAmp;
    } else if ((t -= tJ) < tW) {                   // WORD: still and open, the word on black in the middle
      c = c1; v = v1;
      apart = 1;
      wordA = smooth01(t / 30);
    } else if ((t -= tW) < tC) {                   // CLOSE: once the word is gone, the pieces close up
      c = c1; v = v1;
      apart = 1 - easeInOutCubic(t / tC);
    } else if ((t -= tC) < tX) {                   // COLLAPSE: into one little shard
      float e = t / tX;
      c = c1; v = v1;
      gather = e;   // eased per piece in display()
    } else {                                       // MINI: the little shard wanders all the walls
      gather = 1;
      if (!shrunk && tile != null) {               // it is tiny now: a tiny texture is enough (memory)
        shrunk = true;
        if (tile.tex != null && tile.tex.width > 128) {
          PImage small = tile.tex.copy();
          small.resize(128, 0);
          tile.tex = small;
        }
      }
      if (pos == null) {
        pos  = ringPoint(c, v);
        face = ringFace(c);
        Face f = faces[face];
        vel = PVector.mult(f.eU, (vc > 0 ? 1 : -1) * POEM_MINI_SPEED * spdK);
        up  = new PVector(0, 0, 1);
      }
      wander();
    }
    // Once the cloud is gone, it drifts in and out of the depth, at a pace of its own
    if (age > wordStart) {
      float k = smooth01((age - wordStart) / 600);   // eases in, no jump
      setDepth(depth0 + k * (noise(seed + 300, age * 0.0012 * pace) - 0.5) * 1.6);
    }
    updateWord();
    if (leaving) {
      fade *= 1 - smooth01((age - leaveAge) / 600);
      if (age - leaveAge > 600) tile = null;     // the shard is gone: free its tile (the word stays)
    }
    alpha = POEM_ALPHA * fade * alphaK;
    wordAlpha = POEM_ALPHA * alphaK * (wordLeaving ? 1 - smooth01((age - wordLeaveAge) / 600) : 1);
  }

  // The written word: once its 2 s are over it leaves the tile, glides down the wall and
  // floats on the floor like a leaf on water (no floor in the venue: along the low band of the walls)
  void updateWord() {
    if (age < wordStart) { wc = c; wv = v; return; }
    wordA = 1;
    float t = age - wordStart;
    float vEnd = HAS_FLOOR ? WALL_H : WALL_H - bandV;
    if (t < POEM_DESCEND_FRAMES) {                 // gliding down, swaying a little
      float e = easeInOutCubic(t / POEM_DESCEND_FRAMES);
      wc = c1 + sin(e * PI) * POEM_TILE_SIZE * 0.3 * (vc > 0 ? 1 : -1);
      wv = lerp(v1, vEnd, e);
    } else if (HAS_FLOOR) {
      if (wpos == null) {                          // onto the floor, heading into the room
        Face w = faces[ringFace(wc)];
        wpos = PVector.add(ringPoint(wc, WALL_H), PVector.mult(w.n, 2));
        wpos.z = 0;
        wvel = PVector.mult(w.n, POEM_WORD_SPEED * spdK);
        wup  = PVector.mult(w.n, -1);              // same orientation it had on the wall (unfolded): no flip
      }
      floatOnFloor();
    } else {
      float[] br = bandStretch();
      if (wc < br[0] - 1) wc += ringLength();   // (WALL 2 is after WALL 1 going round)
      wc += wdir * POEM_WORD_SPEED * spdK * (0.7 + 0.6 * noise(seed, age * 0.001));
      if ((wc < br[0] && wdir < 0) || (wc > br[1] && wdir > 0)) wdir = -wdir;   // turns back before the main wall
      wv  = vEnd + sin(age * 0.004 + vPhase) * bandV * 0.35;
    }
  }

  // Floats across the whole floor: it drifts towards a destination anywhere on the floor,
  // with long, gentle curves; when it gets close it picks the next one
  void floatOnFloor() {
    float m = POEM_TILE_SIZE * 0.5;
    if (wtarget == null || dist(wpos.x, wpos.y, wtarget.x, wtarget.y) < POEM_TILE_SIZE * 0.6) {
      Random rt = new Random((long) (seed * 1000) + wlegs * 7919L);   // evenly anywhere on the floor, same on every run
      wtarget = new PVector(rnd(rt, m, ROOM_W - m), rnd(rt, m, ROOM_D - m), 0);
      wlegs++;
    }
    PVector want = new PVector(wtarget.x - wpos.x, wtarget.y - wpos.y, 0).normalize();
    // a gentle sway so it never moves in a straight line
    float sway = (noise(seed + 100, age * 0.002) - 0.5) * 1.2;
    want = new PVector(want.x * cos(sway) - want.y * sin(sway), want.x * sin(sway) + want.y * cos(sway), 0);
    // a little room between the words
    for (PoemWord o : poemWordsList) {
      if (o == this || o.wpos == null) continue;
      float d = dist(wpos.x, wpos.y, o.wpos.x, o.wpos.y);
      float room = POEM_TILE_SIZE * 0.9 * (depS + o.depS);
      if (d < room && d > 0.01) want.add((wpos.x - o.wpos.x) / d * 1.2 * (1 - d / room + 0.3), (wpos.y - o.wpos.y) / d * 1.2 * (1 - d / room + 0.3), 0);
    }
    want.normalize().mult(POEM_WORD_SPEED * spdK * pace * (0.4 + 1.2 * noise(seed + 700, age * 0.003)));
    wvel.lerp(want, 0.012);                        // turns slowly: long, graceful curves
    if (wvel.mag() < POEM_WORD_SPEED * spdK * 0.3) wvel.setMag(POEM_WORD_SPEED * spdK * 0.3);
    wpos.add(wvel);
    wpos.x = constrain(wpos.x, 5, ROOM_W - 5);
    wpos.y = constrain(wpos.y, 5, ROOM_D - 5);
    wpos.z = 0;
    wup.lerp(wvel.copy().normalize(), 0.008);      // slowly turns to read along the way it drifts
    if (wup.mag() < 0.01) wup.set(1, 0, 0);
    wup.normalize();
  }


  // The little shard: free over all the walls (crossing corners), never on the floor
  void wander() {
    Face f = faces[face];
    float turn = (noise(seed, age * 0.003 * pace) - 0.5) * 0.07;   // meandering, never a straight line
    PVector side = f.n.cross(vel);
    vel = PVector.add(PVector.mult(vel, cos(turn)), PVector.mult(side, sin(turn)));
    PVector wallUp = PVector.mult(f.eV, -1);
    up.lerp(wallUp, 0.01);
    if (up.mag() < 0.01) up = wallUp;
    up.normalize();
    float vv = PVector.sub(pos, f.O).dot(f.eV), s = vel.dot(f.eV);
    float gust = 0.35 + 1.3 * noise(seed + 500, age * 0.004);   // speeds up and slows down
    vel.setMag(POEM_MINI_SPEED * spdK * pace * gust);
    if (vv < CEILING_MARGIN * 0.5 && s < 0) vel.add(PVector.mult(f.eV, -2 * s));
    if (vv > f.h - CEILING_MARGIN * 0.5 && s > 0) vel.add(PVector.mult(f.eV, -2 * s));   // stays off the floor
    pos.add(vel);
    int next = foldOver(face, pos, vel, up);
    if (next >= 0 && next != FLOOR) face = next;
  }



  void display(PGraphics pg, Face target) {
    if (tile != null && alpha >= 1) drawCloud(pg, target);
    if (wordA > 0 && wordAlpha >= 1) drawWord(pg, target);   // drawn wherever the word is, whatever the shard does
  }

  void drawCloud(PGraphics pg, Face target) {
    PVector P = (pos != null) ? pos : ringPoint(c, v);
    Face src = faces[(pos != null) ? face : ringFace(c)];
    PVector q = target.localPoint(P, src);
    if (q == null) return;
    float reach = (poemReach() + POEM_TILE_SIZE * 1.5) * max(1, depS) + 20;   // the cloud stretches out while travelling
    if (q.x < -reach || q.x > target.w + reach || q.y < -reach || q.y > target.h + reach) return;

    PVector u = target.localDir(pos != null ? up : new PVector(0, 0, 1), src);
    pg.push();
    pg.translate(q.x, q.y);
    pg.rotate(atan2(u.y, u.x) + HALF_PI);
    pg.noStroke();
    pg.textureMode(NORMAL);
    pg.scale(scl * depS);
    for (int i = 0; i < tile.pieces.size(); i++) {
      Piece p = tile.pieces.get(i);
      boolean mini = (i == miniIdx);
      // First the other pieces vanish, quickly, one by one (no fade); only then does the kept one
      // shrink to the little shard, drifting to the centre and starting to turn
      if (!mini && gather > 0 && gather >= POEM_VANISH_PART * goT[i] / 0.7) continue;
      float a = alpha;
      if (a < 0.5) continue;
      pg.pushMatrix();
      if (mini && gather > 0) {
        float g = easeInOutCubic(constrain((gather - POEM_VANISH_PART) / (1 - POEM_VANISH_PART), 0, 1));
        pg.translate(lerp(p.cx, 0, g), lerp(p.cy, 0, g));
        pg.rotate(max(0, age - (wordStart + tC + POEM_VANISH_PART * tX)) * miniSpin * g);   // starts turning from still
        pg.scale(lerp(1, miniScale, g));
      } else if (gather > 0) {
        pg.translate(p.cx, p.cy);   // still in place until its turn to vanish
      } else {
        float k = 1;
        float ox = p.cx + sx[i] * apart, oy = p.cy + sy[i] * apart;
        // open: keep the middle empty for the word
        float ex = ox / (POEM_TILE_SIZE * 0.55), ey = oy / (POEM_TILE_SIZE * 0.3), er = sqrt(ex * ex + ey * ey);
        if (er < 1 && er > 0.001) { float push = lerp(1, 1 / er, apart); ox *= push; oy *= push; }
        // travelling: each piece runs ahead and falls behind the group, along the way
        float dirX = (c1 >= c0) ? 1 : -1;
        ox += dirX * POEM_TILE_SIZE * travel * (0.6 * lag[i] + 0.35 * sin(age * oscF[i] + oscP[i]));
        // each piece floats on its own (no rigid turning of the whole cloud)
        ox += (noise(seed + i * 3.1, age * 0.004) - 0.5) * POEM_TILE_SIZE * 0.5 * apart;
        oy += (noise(seed + i * 3.1 + 40, age * 0.004) - 0.5) * POEM_TILE_SIZE * 0.35 * apart;
        pg.translate(ox * k, oy * k);
        pg.rotate(spin[i] * apart * (noise(seed + i * 1.7, age * 0.003) * 2 - 0.5));
        pg.scale(max(0.01, k) * pieceS);
      }
      tile.drawPiece(pg, p, a, p.cx, p.cy, dim * dimK);
      pg.popMatrix();
    }
    pg.pop();
  }

  void drawWord(PGraphics pg, Face target) {
    PVector P = (wpos != null) ? wpos : ringPoint(wc, wv);
    Face src = faces[(wpos != null) ? FLOOR : ringFace(wc)];
    PVector q = target.localPoint(P, src);
    if (q == null) return;
    float reach = POEM_TILE_SIZE;
    if (q.x < -reach || q.x > target.w + reach || q.y < -reach || q.y > target.h + reach) return;
    PVector u = target.localDir(wpos != null ? wup : new PVector(0, 0, 1), src);
    pg.push();
    pg.translate(q.x, q.y);
    pg.rotate(atan2(u.y, u.x) + HALF_PI);
    // Always the same text size (each new size would cache a new font in OpenGL and leak memory):
    // the size of the word comes from scaling instead
    pg.textFont(poemFont);
    pg.textAlign(CENTER, CENTER);
    pg.textSize(96);
    pg.scale(POEM_TILE_SIZE * 0.22 * depS * (age < wordStart ? scl : 1) / 96);
    float ta = 100 * wordA * wordAlpha / POEM_ALPHA * dimK;
    for (int k = 0; k < 4; k++) {   // soft dark halo so it reads over anything
      float a = TWO_PI * k / 4 + QUARTER_PI, d = 96 * 0.055;
      pg.fill(225, 50, 8, ta * 0.4);
      pg.text(word, cos(a) * d, sin(a) * d);
    }
    pg.fill(40, 8, 98, ta);
    pg.text(word, 0, 0);
    pg.pop();
  }

  boolean isDead() {
    return wordLeaving && age - wordLeaveAge > 600;
  }
}
