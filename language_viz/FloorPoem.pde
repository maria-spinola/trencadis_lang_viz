// ═══════════════════════════════════════════════════════════
// FloorPoem.pde
// The floor as a page: the poem is written directly on it, verse by verse.
// A verse (two or three lines of the poem, in order) builds word by word with slow
// fades, stays, and fades away while the next one builds in another place.
// Few at once (VERSE_MAX), all read the same way, lots of black around them.
// The visitors' words stay as small footprints along the two ends of the floor:
// they arrive golden, then turn discreet; they never cross the poem.
// "The walls keep the words as matter; the floor keeps them as language."
// Off (ART_FLOOR_POEM = false): the old drifting poem words.
// ═══════════════════════════════════════════════════════════

boolean floorPoemOn() { return art(ART_FLOOR_POEM) && HAS_FLOOR && SHOW_POEM && FLOOR_ECHO == 0; }

String[][] verseBlocks;
int verseNext = 0, laneNext = 0, verseTimer = 60;
float[] LANES = { 0.2, 0.62, 0.4, 0.8 };   // where verses are written across the floor (× its width), in turn

class Verse {
  String[] lines;
  float u, v;           // centre on the floor
  int start, nWords, end;
  int lane;
  Verse(String[] lines, int lane) {
    this.lines = lines; this.lane = lane;
    u = ROOM_W * LANES[lane];
    v = ROOM_D / 2;
    start = frameCount;
    for (String l : lines) nWords += l.split(" ").length;
    end = start + nWords * VERSE_STAGGER + VERSE_FADE_IN + VERSE_STAY;
  }
  boolean done() { return frameCount > end + VERSE_FADE_OUT; }
}

class Footprint {
  String w;
  float u, v;
  int t0, pulse = -99999, gone = -1;
}

ArrayList<Verse> verses = new ArrayList<Verse>();
ArrayList<Footprint> footprints = new ArrayList<Footprint>();
int footCount = 0;

void loadVerseBlocks() {
  String[] l = new String[0];
  try { l = loadJSONObject("poem_words.json").getString("text", "").split("\n"); } catch (Exception e) { }
  ArrayList<String[]> b = new ArrayList<String[]>();
  int i = 0;
  while (i < l.length) {
    int n = (l.length - i == 3) ? 3 : 2;   // pairs of lines; three at the end rather than one alone
    String[] blk = new String[min(n, l.length - i)];
    for (int k = 0; k < blk.length; k++) blk[k] = l[i + k].trim();
    b.add(blk);
    i += blk.length;
  }
  verseBlocks = b.toArray(new String[0][]);
}

void updateFloorPoem() {
  if (!floorPoemOn()) return;
  if (verseBlocks == null) loadVerseBlocks();
  for (int i = verses.size() - 1; i >= 0; i--) if (verses.get(i).done()) verses.remove(i);
  // the next verse begins once the newest one is complete and has been read a while
  boolean ready = verses.size() == 0 || frameCount > verses.get(verses.size() - 1).end - VERSE_STAY / 3;
  if (verseBlocks.length > 0 && verses.size() < VERSE_MAX && ready && --verseTimer <= 0) {
    int lane = laneNext;
    for (int k = 0; k < LANES.length; k++) {   // a place no verse is using now
      boolean used = false;
      for (Verse vv : verses) used |= vv.lane == (laneNext + k) % LANES.length;
      if (!used) { lane = (laneNext + k) % LANES.length; break; }
    }
    verses.add(new Verse(verseBlocks[verseNext % verseBlocks.length], lane));
    verseNext++;
    laneNext = (lane + 1) % LANES.length;
    verseTimer = 40;
  }
  for (int i = footprints.size() - 1; i >= 0; i--) {
    Footprint fp = footprints.get(i);
    if (fp.gone >= 0 && frameCount - fp.gone > 300) footprints.remove(i);
  }
}

// A visitor's word joins the floor as a footprint (WordsSystem.pde: dropTypedWord)
void addFootprint(String w) {
  int alive = 0;
  for (Footprint fp : footprints) if (fp.gone < 0) alive++;
  if (alive >= FOOTPRINT_MAX) for (Footprint fp : footprints) if (fp.gone < 0) { fp.gone = frameCount; break; }   // the oldest fades
  Footprint f = new Footprint();
  f.w = w; f.t0 = frameCount;
  float em = min(ROOM_W, ROOM_D) * FOOTPRINT_EM;
  Random r = new Random(wordSeed(w) + footCount++ * 7919L);
  float best = -1;
  for (int k = 0; k < 60; k++) {   // along the two ends of the floor, clear of the poem and of the other footprints
    float u = ROOM_W * rnd(r, 0.08, 0.92);
    float v = (r.nextBoolean()) ? ROOM_D * rnd(r, 0.05, 0.13) : ROOM_D * rnd(r, 0.87, 0.95);
    float d = Float.MAX_VALUE;
    for (Footprint o : footprints) if (o.gone < 0) d = min(d, dist(u, v * 0.35, o.u, o.v * 0.35));   // (words run along v: more room needed that way)
    if (d > best) { best = d; f.u = u; f.v = v; }
    if (d > em * 6) break;
  }
  footprints.add(f);
}

void pulseFootprints(String w) {
  for (Footprint fp : footprints) if (fp.w.equalsIgnoreCase(w)) fp.pulse = frameCount;
}

void drawFloorPoem(PGraphics pg, Face f) {
  if (!floorPoemOn() || f.id != FLOOR) return;
  if (poemFont == null) poemFont = createFont(TEXT_FONT, 96);
  pg.textFont(poemFont);
  pg.textSize(96);
  pg.textAlign(LEFT, CENTER);
  float side = min(ROOM_W, ROOM_D);
  // the verses
  for (Verse vs : verses) {
    float em = side * VERSE_EM, k = em / 96;
    float out = 1 - smooth01((frameCount - vs.end) / (float) VERSE_FADE_OUT);
    pg.pushMatrix();
    pg.translate(vs.u, vs.v);
    pg.rotate(HALF_PI);                       // all verses read the same way, facing the main wall
    pg.scale(k);
    int w = 0;
    for (int li = 0; li < vs.lines.length; li++) {
      String[] ws = vs.lines[li].split(" ");
      float lineW = pg.textWidth(vs.lines[li]);
      float x = -lineW / 2, y = (li - (vs.lines.length - 1) / 2.0) * 96 * 1.55;
      for (String word : ws) {
        float a = smooth01((frameCount - vs.start - w * VERSE_STAGGER) / (float) VERSE_FADE_IN) * out;
        if (a > 0.003) {
          pg.fill(hexColor(VERSE_COLOR), VERSE_ALPHA * a);
          pg.text(word, x, y);
        }
        x += pg.textWidth(word + " ");
        w++;
      }
    }
    pg.popMatrix();
  }
  // the visitors' footprints
  for (Footprint fp : footprints) {
    float age = frameCount - fp.t0;
    float a = smooth01(age / 90.0) * (fp.gone >= 0 ? 1 - smooth01((frameCount - fp.gone) / 300.0) : 1);
    float gold = 1 - smooth01((age - FOOTPRINT_GOLD_FRAMES) / 300.0);
    gold = max(gold, sin(PI * constrain((frameCount - fp.pulse) / 120.0, 0, 1)));   // its tile has just settled
    float alpha = lerp(FOOTPRINT_ALPHA, 95, gold) * a;
    if (alpha < 0.3) continue;
    float em = side * FOOTPRINT_EM * (1 + 0.25 * gold);
    pg.pushMatrix();
    pg.translate(fp.u, fp.v);
    pg.rotate(HALF_PI);
    pg.scale(em / 96);
    pg.textAlign(CENTER, CENTER);
    pg.fill(mixRGB(hexColor(FOOTPRINT_COLOR), hexColor(TYPED_NEW_COLOR), gold), alpha);
    pg.text(fp.w, 0, 0);
    pg.popMatrix();
  }
  pg.textAlign(LEFT, CENTER);
}
