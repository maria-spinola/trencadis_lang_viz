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
String UI_STONE_TEXT_COLOR = "#F1E9DA";   // on the stone backdrop: the text box's words and messages, lighter (they must stand out on it)
String UI_MESSAGE_COLOR   = "#959595";   // messages: "Aquesta paraula no és catalana", "Volies dir «cafè»?"…
String UI_TEST_COLOR      = "#FF9F19";   // "TEST MODE" (only in test mode)
String UI_BAR_COLOR       = "#000000";   // band behind the box (how dark: UI_BAR_ALPHA in Config; 0 = none)

// ── Words on the floor ────────────────────────────────────────
String TYPED_WORD_COLOR   = "#FAF3E6";
String TYPED_NEW_COLOR    = "#F2C46A";
// The haze of colour behind the mural (Backdrop.pde, BACKDROP "glow"): the trencadís' own glazes
String[] BACKDROP_COLORS = { "#C08A2E", "#B5502E", "#139F9A", "#E07A1F", "#2455C4", "#DDAE32", "#36954F", "#C8402E" };   // (up to 8; they blend into each other in this order)
// The natural stone (BACKDROP "stone")
String[] STONE_COLORS  = { "#9C8870", "#BBA88A", "#7A6A57", "#D4C6AA" };   // two stones of the strata, a darker mottling, the veins
String FX_BED_COLOR       = "#2B2723";   // the bed of mortar a tile leaves when it comes out of the wall (WallMoments.pde)
String POEM_FLOOR_COLOR   = "#E9E3D6";   // the poem's words on the floor: paler than the visitors', whitish but not pure white
String VERSE_COLOR        = "#F3EEE4";   // the poem's verses on the floor   // a visitor's word while it is new on the floor (warm gold)
String WARM_LIGHT_COLOR   = "#FFD9A0";
String AMBIENT_LIGHT_COLOR = "#FFF0DA";  // the calm light wandering along the mural   // the light of the stream, the impact and the wave (warm, never white)   // the visitors' words (TYPED_WORDS_TO_FLOOR)
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
// ── Two palettes (PALETTE in Config.pde) ──────────────────────
// "viva": bright, strong glazes — cobalt, ultramarine, turquoise, jade, raspberry; bright grounds,
//         coloured ribbons (the default)
// "terracota": the earthy Park Güell look — ochre, khaki, brown, cobalt; ivory and mustard
//         grounds, ochre and brown ribbons; violets become cobalt and pinks red
// Every tile is baked again at start, so the whole mural changes with it. The emotion → colour
// table above is the same for both.
final boolean TERRACOTA = paletteIs("terracota");
boolean paletteIs(String name) { return PALETTE.equalsIgnoreCase(name); }   // (PALETTE is a constant: safe before Config.pde is read)

// Every colour is moved to the nearest of these glaze hues (0–360 on the colour wheel)
float[] GLAZE_HUES = TERRACOTA
  ? new float[] { 2, 12, 18, 30, 42, 72, 142, 185, 210 }                 // red, terracotta, brick, orange, ochre, olive, green, turquoise, cobalt
  : new float[] { 2, 12, 30, 48, 115, 150, 178, 198, 222, 242, 335 };    // + yellow, leaf, jade, sky, ultramarine, raspberry

// ── The ceramic ───────────────────────────────────────────────
String TILE_CREAM_COLOR   = TERRACOTA ? "#F1E3C2" : "#EEE8DD";   // the ivory ground of some painted tiles (warm, never paper white)
// Grounds of the painted tiles — terracota: ivory, mustard, sand, porcelain, celadon; viva: sky, jade, rose, leaf, yellow, ivory
String[] GROUND_COLORS = TERRACOTA
  ? new String[] { "#F1E6CF", "#E8C46C", "#D8BE94", "#F4EEE2", "#C9DCD2" }
  : new String[] { "#75C7DE", "#66C6AF", "#E899B4", "#A9CA75", "#F0CE63", "#EEE8DD" };
// Glazes among the shards from other tiles — terracota: khaki, ochre-brown, mauve, teal; viva: cobalt, turquoise, rose, leaf, coral
String[] EARTH_COLORS = TERRACOTA
  ? new String[] { "#9C8A5E", "#A8743A", "#C98A9A", "#3E8C86", "#7A5A3A" }
  : new String[] { "#2455C4", "#069D98", "#D84683", "#36954F", "#E56C48" };
String TEAL_COLOR         = TERRACOTA ? "#2E8C84" : "#079D99";
String LEAF_COLOR         = TERRACOTA ? "#3E8F3A" : "#389D48";
// Bold geometric tiles (phenomenon 6): near black and a strong yellow, as on the benches
String GEO_DARK_COLOR     = TERRACOTA ? "#17120E" : "#141D30";
String GEO_LIGHT_COLOR    = TERRACOTA ? "#EBA51E" : "#F2C438";
float  GEO_LIGHT_SHARE    = TERRACOTA ? 0.6 : 0.25;   // how often they take that yellow (else the word's own colour)
// Heraldic tiles: cobalt ground with golden stars
String HERALD_COLOR       = TERRACOTA ? "#1D4FA6" : "#2455C4";
String STAR_COLOR         = "#F2B92A";
// Glass (rare words): coloured glass shards and round bottle bottoms, as in Gaudí's mosaics
String[] GLASS_COLORS     = { "#1B46B8", "#1F8A3E", "#B8680E", "#7FC6C0", "#5B2A86" };
String CROCKERY_COLOR     = "#F2EEE4";   // the few white "crockery" shards among the coloured ones
String GOLD_LUSTRE_COLOR  = "#E8B73A";   // golden lustre shards of rare words (raresa)
String GROUT_COLOR        = TERRACOTA ? "#9A9285" : "#A7A6A0";   // the lime mortar between the shards, once dry
String BODY_TERRACOTTA    = "#B8784F";   // the fired clay under the glaze, where it chipped (most tiles)…
String BODY_CREAM         = "#E2D3B8";   // …or a pale body (the rest)
String SKY_REFLECTION     = "#F2F6FB";   // what the glaze reflects: a bright sky
// Glazes of the moulded relief tiles (leaves and berries, as on the benches)
String[] RELIEF_GLAZES = TERRACOTA
  ? new String[] { "#2F7A34", "#3C8A3A", "#C9952C", "#2A5AA6", "#7A4A2A" }
  : new String[] { "#258449", "#45A14E", "#DCB532", "#2859BD", "#AE3C70" };

// The ribbon along the top of the tiles, one tone per band of the mural (top band first;
// they repeat if there are more bands). Each tile tints it a little with its own colour.
String[] RIBBON_COLORS = TERRACOTA
  ? new String[] {   // the glazed capping of the benches: ochre, brown, khaki, green, amber, dark brown
      "#B98B4E", "#6E4A2C", "#8F8A55", "#4E6B3E", "#A87A44", "#5C3D2B" }
  : new String[] {   // coloured capping: cobalt, turquoise, raspberry, green, yellow, navy
      "#2355AE", "#108F91", "#B63B70", "#36834B", "#DDAE32", "#314889" };

// The border round the top of the room (Cenefa.pde) when CENEFA_POEM is off: its glazes, in turn
String[] CENEFA_COLORS = {   // a steady rhythm, so it reads as a border against the mural
  "#1F4E9C",                       // cobalt
  "#E6DDC8",                       // white crockery
  TERRACOTA ? "#C08A2E" : "#139F9A",   // ochre / turquoise
  "#E6DDC8"                        // white crockery
};

// ── Room view (Ctrl+I) only — never in the output: what isn't projected, so the walls stand out ──
String ROOM_SHELL_COLOR  = "#0B0A0A";   // the ceiling and the wall above the image, unlit (light from the projection is added)
String ROOM_VIEW_OUTSIDE = "#2B3240";   // background
String ROOM_VIEW_CEILING = "#3A4354";   // ceiling
String ROOM_VIEW_FLOOR   = "#323A49";   // floor, when the venue has no floor projection

// ── Typeface ──────────────────────────────────────────────────
// For the words on the floor, the poem and the text box on the main wall
String TEXT_FONT = "Georgia";


// ════════ (below: conversions used by the code) ════════

// two colours mixed in RGB (k 0 = a, 1 = b), whatever the colour mode
int mixRGB(int a, int b, float k) {
  int r = round(lerp((a >> 16) & 255, (b >> 16) & 255, k)), g = round(lerp((a >> 8) & 255, (b >> 8) & 255, k)), bl = round(lerp(a & 255, b & 255, k));
  return 0xFF000000 | (r << 16) | (g << 8) | bl;
}

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

// Companion glazes: selected by hue relation, not an extra random draw.
// The word retains its base; its pattern gets a contrasting and an analogous ink.
float ceramicHueDistance(float a, float b) {
  return abs(((a - b) % 360 + 540) % 360 - 180);
}
