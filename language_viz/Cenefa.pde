// ═══════════════════════════════════════════════════════════
// Cenefa.pde
// A border of trencadís running round the top of the room, over the four walls
// (WALL 4 → 1 → 2 → 3 and back), like the glazed capping of the Park Güell benches.
// Its lower edge waves like the bands of the mural, its joins run at odd angles.
// CENEFA_POEM: every cell is a word of the poem (its colour, motif and cuts from its analysis
// in poem_words.json), in order round the room; otherwise glazes in turn (CENEFA_COLORS). Baked once at start into a layer per wall and drawn under
// the same live light as the mural, so the waves of a settling tile also run along it.
// The mural sits just below it (Mosaic.pde: bandY). Settings: CENEFA_* in Config.pde.
// ═══════════════════════════════════════════════════════════

PGraphics[] cenefaLayers = new PGraphics[5];
PGraphics[] cenefaGloss  = new PGraphics[5];

// Where the mural begins under the border (on average)
float muralTop() { return CENEFA ? WALL_H * (CENEFA_H + CENEFA_GAP) : 0; }

// The lower edge of the border: a wave like the bands of the mural. X runs round the ring as in
// bandY (Mosaic.pde: WALL 1 from 0, WALL 2 from ROOM_D, WALL 3 from ROOM_D + ROOM_W, WALL 4 from
// −ROOM_W); whole numbers of waves round the room, so it closes on itself at every corner.
float cenefaEdge(float X) {
  if (!CENEFA) return 0;
  float L = 2 * (ROOM_W + ROOM_D), h = WALL_H * CENEFA_H;
  return h * (1 + CENEFA_WAVE * (sin(TWO_PI * 9 * X / L + 1.3) + 0.35 * sin(TWO_PI * 23 * X / L + 4.1)) / 1.35);
}

float ringStart(int w) {
  if (w == W1) return 0;
  if (w == W2) return ROOM_D;
  if (w == W3) return ROOM_D + ROOM_W;
  return -ROOM_W;   // WALL 4
}

void setupCenefa() {
  if (!CENEFA) return;
  int t0 = millis();
  int[] ring = { W4, W1, W2, W3 };   // in order round the room: each wall ends where the next one begins
  float h = WALL_H * CENEFA_H;
  Random r = new Random(MOSAIC_SEED * 101L + 7);
  JSONArray poem = null;   // CENEFA_POEM: every cell is a word of the poem, in order round the room
  if (CENEFA_POEM) try { poem = loadJSONObject("poem_words.json").getJSONArray("words"); } catch (Exception e) { }
  if (poem != null && poem.size() == 0) poem = null;
  int cell = 0, tiles = 0;
  float savedK = bakeDetailK;
  bakeDetailK = BAKE_DETAIL_MURAL;
  try {
    for (int w : ring) {
      Face f = faces[w];
      float xo = ringStart(w);
      cenefaLayers[w] = createGraphics(f.pg.width, f.pg.height, P2D);
      if (CERAMIC_BAKE) cenefaGloss[w] = createGraphics(f.pg.width, f.pg.height, P2D);
      // the joins, at odd angles as in the mural (straight at the corners)
      FloatList xs = new FloatList(), sl = new FloatList();
      xs.append(0); sl.append(0);
      float x = 0;
      while (true) {
        x += h * rnd(r, CENEFA_CELL_MIN, CENEFA_CELL_MAX);
        if (f.w - x < h * CENEFA_CELL_MIN * 0.8) break;
        xs.append(x);
        sl.append(rnd(r, -1, 1) * h * CENEFA_SLANT);
      }
      xs.append(f.w); sl.append(0);
      for (int i = 0; i < xs.size() - 1; i++, cell++) {
        float a = xs.get(i), b = xs.get(i + 1), sa = sl.get(i), sb = sl.get(i + 1);
        // the bottom edge follows the wave, in straight facets like the mural's bands
        float b0 = a - sa, b1 = b - sb;
        int n = max(2, ceil((b1 - b0) / (h * 0.7)));
        PVector[] bot = new PVector[n + 1];
        for (int k = 0; k <= n; k++) { float bx = lerp(b0, b1, k / (float) n); bot[k] = new PVector(bx, cenefaEdge(bx + xo)); }
        Patch p = new Patch(new PVector[] { new PVector(a + sa, 0), new PVector(b + sb, 0) }, bot);
        TrencadisTile t;
        if (poem != null) {
          JSONObject word = poem.getJSONObject(cell % poem.size());
          t = makeWordTile(word, p, CENEFA_RIBBON, WALL_H / MOSAIC_ROWS * CENEFA_SHARD);
        } else {
          boolean painted = CENEFA_PAINTED_EVERY > 0 && cell % CENEFA_PAINTED_EVERY == CENEFA_PAINTED_EVERY - 1;
          String hex = CENEFA_COLORS[cell % CENEFA_COLORS.length];
          nextTileStyle = cell & 3;
          nextTileGlaze = painted ? null : hsbOf(hex);
          try {
            t = new TrencadisTile(MOSAIC_SEED * 977L + cell * 7919L, parseHexColor(hex), 4, 3, painted ? 5 : 2, 1, p,
                                  CENEFA_RIBBON, 0, 0, WALL_H / MOSAIC_ROWS * CENEFA_SHARD);
          } finally { nextTileStyle = -1; nextTileGlaze = null; }
        }
        t.face = w;
        stampInto(t, cenefaLayers[w], cenefaGloss[w]);
        tiles++;
      }
    }
  } finally { bakeDetailK = savedK; }
  println("Cenefa: " + tiles + " tiles round the room" + (poem != null ? " (words of the poem)" : "") + " (" + (millis() - t0) + " ms)");
}

// A tile set into a layer (and its relief into the gloss layer), as on the mural
void stampInto(TrencadisTile tile, PGraphics L, PGraphics G) {
  if (tile.bakeAll != null) {
    int[] at = new int[2];
    PImage st = muralStamp(tile, tile.bakeAll, RENDER_SCALE, at);
    L.beginDraw();
    L.image(st, at[0], at[1]);
    L.endDraw();
    if (G != null && tile.bakeGloss != null) {
      PImage gs = muralStamp(tile, tile.bakeGloss, RENDER_SCALE, at);
      G.beginDraw();
      G.image(gs, at[0], at[1]);
      G.endDraw();
    }
    return;
  }
  L.beginDraw();
  L.colorMode(HSB, 360, 100, 100, 100);
  L.pushMatrix();
  L.scale(RENDER_SCALE);
  L.translate(tile.origin.x, tile.origin.y);
  tile.drawFlat(L, 100, true);
  L.popMatrix();
  L.endDraw();
}

void drawCenefa(PGraphics pg, Face f) {
  if (!CENEFA || cenefaLayers[f.id] == null) return;
  if (art(ART_MURAL_LIGHT) && cenefaGloss[f.id] != null) drawLitLayer(pg, f, cenefaLayers[f.id], cenefaGloss[f.id]);   // Mural.pde
  else pg.image(cenefaLayers[f.id], 0, 0, f.w, f.h);
}
