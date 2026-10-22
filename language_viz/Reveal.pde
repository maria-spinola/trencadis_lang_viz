// ═══════════════════════════════════════════════════════════
// Reveal.pde
// On ENTER the word appears big on the main wall, just over the text box, under the place where
// its tile will form (holdLayout: the border's height, the word and the tile always fit). After WORD_SHOW_FRAMES the tile fades in above it (Mosaic.pde: tileA); the
// word stays under its tile until the tile breaks and leaves, then fades. If it is rejected,
// it simply fades away.
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

// ── The main wall's layout for a new word ──
// From the top: the border (Cenefa.pde), the tile, the word, the text box (its messages under it). The
// word sits just over the box and the tile just over the word (WORD_TILE_GAP), shrinking if it must,
// so nothing overlaps whatever the border's height (CENEFA_H, CENEFA_WAVE) or the word's size.
float holdTopY() {   // under the border at its lowest
  return (CENEFA ? WALL_H * (CENEFA_H * (1 + CENEFA_WAVE) + CENEFA_GAP) : 0) + faces[W3].h * 0.025;
}
float msgTopY() {    // just over the line being typed in the text box (its messages go under it: ClaudeSketch.pde)
  Face m = faces[W3];
  float ui = m.h / 900.0 * UI_SCALE;
  return m.h * UI_Y + 90 * ui * 0.5 - 12 * ui - m.h * 0.015;
}
float revealWordY() { return msgTopY() - faces[W3].h * WORD_REVEAL_SIZE * 0.42; }
float holdBottomY() {   // the lowest the tile may reach
  if (!art(ART_WORD_REVEAL)) return msgTopY();
  return revealWordY() - faces[W3].h * (WORD_REVEAL_SIZE * 0.42 + WORD_TILE_GAP);
}
float holdCentreY() { return art(ART_WORD_REVEAL) ? (holdTopY() + holdBottomY()) / 2 : faces[W3].h * HOLD_Y; }

void endReveal() { if (revealEnd < 0 && revealWord.length() > 0) revealEnd = frameCount; }

// When the crossfade into the tile may start (the word has been seen alone long enough)
int revealCrossfadeStart(String w) {
  if (!revealWord.equalsIgnoreCase(w)) return frameCount;
  return max(frameCount, revealStart + WORD_SHOW_FRAMES);
}

float revealAlpha() {
  if (revealWord.length() == 0) return 0;
  float a = smooth01((frameCount - revealStart) / (float) WORD_IN_FRAMES);
  if (revealFlight != null && revealFlight.departFrame >= 0) a *= 1 - smooth01((frameCount - revealFlight.departFrame) / 40.0);   // the tile has left
  if (revealEnd >= 0) a *= 1 - smooth01((frameCount - revealEnd) / 30.0);
  if (a < 0.002 && frameCount - revealStart > WORD_IN_FRAMES) { revealWord = ""; return 0; }
  return a;
}

// Drawn on WALL 3, under the forming tile (Room.pde)
void drawRevealWord(PGraphics pg, Face f) {
  float a = revealAlpha();
  if (a <= 0.002 || f.id != W3) return;
  if (poemFont == null) poemFont = createFont(TEXT_FONT, 96);
  pg.textFont(poemFont);
  pg.textSize(96);
  float size = f.h * WORD_REVEAL_SIZE;
  float tw = pg.textWidth(revealWord) * size / 96;
  if (tw > f.w * WORD_MAX_WIDTH) size *= f.w * WORD_MAX_WIDTH / tw;
  drawWordLabel(pg, revealWord, f.w / 2, revealWordY(), size, a);
}
