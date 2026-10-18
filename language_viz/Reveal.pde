// ═══════════════════════════════════════════════════════════
// Reveal.pde
// On ENTER the word appears very big, centred where its tile will form on the main
// wall. After WORD_SHOW_FRAMES it crossfades into the tile (Mosaic.pde: tileA), in the
// same place: the word turns into matter. If it is rejected, it simply fades away.
// ═══════════════════════════════════════════════════════════

String revealWord = "";
int revealStart = -99999, revealEnd = -1;
TileFlight revealFlight;

void startReveal(String w) {
  if (!art(ART_WORD_REVEAL)) return;
  revealWord = w;
  revealStart = frameCount;
  revealEnd = -1;
  revealFlight = null;
}

void endReveal() { if (revealEnd < 0 && revealWord.length() > 0) revealEnd = frameCount; }

// When the crossfade into the tile may start (the word has been seen alone long enough)
int revealCrossfadeStart(String w) {
  if (!revealWord.equalsIgnoreCase(w)) return frameCount;
  return max(frameCount, revealStart + WORD_SHOW_FRAMES);
}

float revealAlpha() {
  if (revealWord.length() == 0) return 0;
  float a = smooth01((frameCount - revealStart) / (float) WORD_IN_FRAMES);
  if (revealFlight != null && revealFlight.xStart >= 0) a *= 1 - smooth01((frameCount - revealFlight.xStart) / (float) WORD_XFADE_FRAMES);
  if (revealEnd >= 0) a *= 1 - smooth01((frameCount - revealEnd) / 30.0);
  if (a < 0.002 && frameCount - revealStart > WORD_IN_FRAMES) { revealWord = ""; return 0; }
  return a;
}

// Drawn on WALL 3 over the forming tile (Room.pde)
void drawRevealWord(PGraphics pg, Face f) {
  float a = revealAlpha();
  if (a <= 0.002 || f.id != W3) return;
  if (poemFont == null) poemFont = createFont(TEXT_FONT, 96);
  pg.textFont(poemFont);
  pg.textSize(96);
  float size = f.h * WORD_REVEAL_SIZE;
  float tw = pg.textWidth(revealWord) * size / 96;
  if (tw > f.w * WORD_MAX_WIDTH) size *= f.w * WORD_MAX_WIDTH / tw;
  drawWordLabel(pg, revealWord, f.w / 2, f.h * HOLD_Y, size, a);
}
