// ═══════════════════════════════════════════════════════════
// Motes.pde
// Little shards of tile floating, very faintly, in the empty parts of the walls.
// Real baked shards (tiles made from the words of the poem), drifting slowly round the
// room, turning and tumbling, each at its own depth: far ones small, dark, slow and faint,
// near ones bigger and clearer. They pass behind the mural and the border (drawn before them),
// so they only show where the walls are still empty. They fade while a word is on its way.
// Settings: MOTES_* in Config.pde (MOTES = false: none).
// ═══════════════════════════════════════════════════════════

ArrayList<TrencadisTile> moteTiles = new ArrayList<TrencadisTile>();
ArrayList<int[]> moteSrc = new ArrayList<int[]>();   // { tile, piece } of every usable shard
float[][] motes;                                      // per mote: X0, y0, depth, speed, phase, spin, source, dir

// Where each wall starts round the ring (WALL 4 → 1 → 2 → 3), its local x running along it
float moteRingStart(int w) {
  if (w == W4) return 0;
  if (w == W1) return ROOM_W;
  if (w == W2) return ROOM_W + ROOM_D;
  return 2 * ROOM_W + ROOM_D;   // WALL 3
}

void setupMotes() {
  if (!MOTES) return;
  Random r = new Random(MOSAIC_SEED * 53L + 11);
  JSONArray words = null;
  try { words = loadJSONObject("poem_words.json").getJSONArray("words"); } catch (Exception e) { }
  float savedK = bakeDetailK;
  bakeDetailK = BAKE_DETAIL_POEM;
  try {
    for (int k = 0; k < 8; k++) {
      TrencadisTile t;
      Patch p = freePatch(r, 170, 140);
      if (words != null && words.size() > 0) t = makeWordTile(words.getJSONObject(r.nextInt(words.size())), p, -1, 0);
      else t = new TrencadisTile(r.nextLong(), parseHexColor(emotionHex(1 + r.nextInt(7), 0, 70, 80)), 4, 4, 1 + r.nextInt(7), 1, p, -1);
      moteTiles.add(t);
      for (int i = 0; i < t.pieces.size(); i++) if (t.pieces.get(i).area > 120) moteSrc.add(new int[] { k, i });   // no crumbs
    }
  } finally { bakeDetailK = savedK; }
  if (moteSrc.size() == 0) return;
  float L = 2 * (ROOM_W + ROOM_D);
  motes = new float[MOTES_COUNT][];
  for (int i = 0; i < MOTES_COUNT; i++) {
    float d = pow(r.nextFloat(), 1.4);   // more far ones than near ones
    motes[i] = new float[] {
      r.nextFloat() * L,                                   // X0 round the ring
      lerp(muralTop() + WALL_H * 0.05, WALL_H * 0.92, r.nextFloat()),   // height
      d,                                                   // depth: 0 far … 1 near
      rnd(r, 0.6, 1.4),                                    // its own pace
      rnd(r, 0, TWO_PI),                                   // phase
      rnd(r, 0.3, 1) * (r.nextBoolean() ? 1 : -1),         // spin
      r.nextInt(moteSrc.size()),                           // which shard
      r.nextFloat() < 0.7 ? 1 : -1 };                      // most go one way round the room, some the other
  }
  java.util.Arrays.sort(motes, (a, b) -> Float.compare(a[2], b[2]));   // far ones drawn first
}

float motesK = 1;   // fades while someone interacts

void drawMotes(PGraphics pg, Face f) {
  if (!MOTES || motes == null || f.id == FLOOR) return;
  if (f.id == W1) motesK = lerp(motesK, 1 - 0.7 * interactK, 0.05);   // (once per frame)
  float L = 2 * (ROOM_W + ROOM_D), x0 = moteRingStart(f.id), t = frameCount;
  pg.pushStyle();
  pg.noStroke();
  pg.textureMode(NORMAL);
  for (float[] m : motes) {
    float d = m[2];
    float size = MOTES_SIZE * lerp(0.35, 1, d);
    float X = m[0] + m[7] * t * MOTES_SPEED * m[3] * lerp(0.3, 1, d);   // far ones slower (parallax)
    float lx = ((X - x0) % L + L) % L;
    if (lx > f.w + size) { if (lx - L < -size) continue; lx -= L; }   // only near this wall
    float y = m[1] + WALL_H * 0.04 * sin(t * 0.004 * m[3] + m[4]) + WALL_H * 0.015 * sin(t * 0.011 + m[4] * 2);
    float a = MOTES_ALPHA * lerp(0.25, 1, d) * motesK;
    // near the edges of the projected wall they fade, never cut
    a *= constrain((y - muralTop()) / (WALL_H * 0.05), 0, 1) * constrain((WALL_H - y) / (WALL_H * 0.06), 0, 1);
    if (f.id == MAIN_FACE) a *= 1 - 0.8 * exp(-sq((lx - f.w / 2) / (f.w * 0.22)));   // clear of the word and the tile forming
    if (a < 0.5) continue;
    int[] src = moteSrc.get((int) m[6]);
    TrencadisTile tile = moteTiles.get(src[0]);
    Piece p = tile.pieces.get(src[1]);
    float sc = size / sqrt(p.area);
    pg.pushMatrix();
    pg.translate(lx, y);
    pg.rotate(t * 0.006 * m[5] + m[4]);
    float flip = cos(t * 0.009 * m[3] + m[4]);   // tumbling: seen edge-on now and then
    pg.scale(sc * (0.2 + 0.8 * abs(flip)), sc);
    tile.drawPiece(pg, p, a, p.cx, p.cy, lerp(MOTES_FAR_DIM, 1, d));
    pg.popMatrix();
  }
  pg.popStyle();
}
