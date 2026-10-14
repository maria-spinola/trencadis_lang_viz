// ═══════════════════════════════════════════════════════════
// Colors.pde
// Every colour of the installation, in one place. Colours are
// written as "#RRGGBB" (any colour picker gives them); the
// numbers after them are what they are now.
// The typeface is TEXT_FONT, at the end.
// ═══════════════════════════════════════════════════════════

// ── The room ───────────────────────────────────────────────
String BACKGROUND_COLOR   = "#000000";   // background of every wall and the floor

// ── Text box on the main wall (what the public types) ─────────
String UI_INPUT_COLOR     = "#9C9C9C";   // the word being typed and its cursor
String UI_PROMPT_COLOR    = "#404040";   // the ">" before it
String UI_LINE_COLOR      = "#2A2A2A";   // the thin line over the box
String UI_LAST_COLOR      = "#393939";   // "↳ last word" above the line
String UI_MESSAGE_COLOR   = "#959595";   // messages: "Aquesta paraula no és catalana", "Volies dir «cafè»?"…
String UI_TEST_COLOR      = "#FF9F19";   // "TEST MODE" (only in test mode)
String UI_BAR_COLOR       = "#000000";   // band behind the box (how dark: UI_BAR_ALPHA in Config; 0 = none)

// ── Words on the floor ────────────────────────────────────────
String POEM_WORD_COLOR    = "#FAF3E6";   // the poem's words
String TYPED_WORD_COLOR   = "#FAF3E6";   // the visitors' words (TYPED_WORDS_TO_FLOOR)
String WORD_HALO_COLOR    = "#0A0D14";   // soft dark halo around every word, so it reads over anything

// ── The tile while it assembles on the main wall ──────────────
String HOLD_PANEL_COLOR   = "#000000";   // see-through window behind it (how dark: HOLD_PANEL_ALPHA in Config)

// ── Colour of each tile, from its emotion ─────────────────────
// "model": the colour the language model chose (it follows this same table in the prompt, with
//          shades: lighter for gentle words, deeper for intense ones)
// "table": always exactly the colour of this table
String EMOTION_COLOR_SOURCE = "model";
String[] EMOTION_COLORS = {
  "#B3261E",   // 1 Ira       red
  "#D9A21B",   // 2 Sorpresa  ochre
  "#A0522D",   // 3 Por       terracotta
  "#C8402E",   // 4 Amor      warm red
  "#1E5E3A",   // 5 Fàstic    bottle green
  "#1F4E9C",   // 6 Tristesa  cobalt
  "#E07A1F"    // 7 Alegria   orange
};
// Every colour is then moved to the nearest of these Park Güell glaze hues (0–360 on the colour
// wheel: 2 red, 12 terracotta, 18 brick, 30 orange, 42 ochre, 72 olive, 142 green, 185 turquoise,
// 210 cobalt). Violets become cobalt and pinks red (Trencadis.pde, ceramicHue).
float[] GLAZE_HUES = { 2, 12, 18, 30, 42, 72, 142, 185, 210 };

// ── The ceramic ───────────────────────────────────────────────
String TILE_CREAM_COLOR   = "#F5F0E4";   // the white / cream ground of the painted tiles
String CROCKERY_COLOR     = "#F2EEE4";   // the few white "crockery" shards among the coloured ones
String GOLD_LUSTRE_COLOR  = "#DBB753";   // golden lustre shards of rare words (raresa)
String GROUT_COLOR        = "#CCC8C2";   // the cement between the shards, once dry

// The dark ribbon along the top of the tiles, one tone per band of the mural (top band first;
// they repeat if there are more bands). Each tile tints it a little with its own colour.
String[] RIBBON_COLORS = {
  "#5C3E29",   // brown
  "#355D61",   // deep teal
  "#383531",   // near black
  "#946C34",   // ochre
  "#355243",   // bottle green
  "#663733"    // oxblood
};

// ── Typeface ──────────────────────────────────────────────────
// For the words on the floor, the poem and the text box on the main wall
String TEXT_FONT = "Georgia";


// ════════ (below: conversions used by the code) ════════

// "#RRGGBB" → a colour for fill() / stroke(), whatever the colour mode
int hexColor(String hex) {
  hex = hex.trim();
  if (hex.startsWith("#")) hex = hex.substring(1);
  try { return 0xFF000000 | Integer.parseInt(hex, 16); } catch (Exception e) { return 0xFFFF00FF; }
}

// "#RRGGBB" → { hue 0–360, saturation 0–100, brightness 0–100 }
float[] hsbOf(String hex) {
  int c = hexColor(hex);
  float[] v = java.awt.Color.RGBtoHSB((c >> 16) & 255, (c >> 8) & 255, c & 255, null);
  return new float[] { v[0] * 360, v[1] * 100, v[2] * 100 };
}

float[][] hsbList(String[] hexes) {
  float[][] out = new float[hexes.length][];
  for (int i = 0; i < hexes.length; i++) out[i] = hsbOf(hexes[i]);
  return out;
}

float[][] RIBBON_TONES = hsbList(RIBBON_COLORS);
float[]   GOLD_LUSTRE  = hsbOf(GOLD_LUSTRE_COLOR);
float[]   GROUT_HSB    = hsbOf(GROUT_COLOR);
float     GROUT_H = GROUT_HSB[0], GROUT_S = GROUT_HSB[1], GROUT_B = GROUT_HSB[2];

// Hue of each emotion (for the colour when no model answers)
float[] emotionHues() {
  float[] h = new float[EMOTION_COLORS.length];
  for (int i = 0; i < h.length; i++) h[i] = hsbOf(EMOTION_COLORS[i])[0];
  return h;
}

// The colour a tile is painted with: the model's, or the table's (EMOTION_COLOR_SOURCE)
String tileHex(String modelHex, int emotion) {
  if (EMOTION_COLOR_SOURCE.equals("table")) return EMOTION_COLORS[constrain(emotion, 1, 7) - 1];
  return modelHex;
}
