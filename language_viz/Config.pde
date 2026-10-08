// ═══════════════════════════════════════════════════════════
// Config.pde
// Global variables and shared utilities.
// ═══════════════════════════════════════════════════════════

// ── VENUE / OUTPUT ──────────────────────────────────────────
// Which room:
//   0 = Florida media matrix: 4 walls + floor, 6650 x 6700 matrix (PIXERA)
//   1 = La Salle IASLab immersive room: 4 walls, NO floor (Watchout, real time via NDI)
//       FRONT / BACK 3206 x 1200 px (7 m), LEFT / RIGHT 4966 x 1200 px (10.844 m), projected height 2.7 m
//       WALL 3 = FRONT (main wall: text input), WALL 1 = BACK (mural), WALL 2 = LEFT, WALL 4 = RIGHT
final int VENUE = 0;
final boolean HAS_FLOOR = (VENUE != 1);   // no floor: it is not rendered, pieces never travel over it
// Sizes in units = output pixels at RENDER_SCALE 1.0.
final float ROOM_W = (VENUE == 1) ? 4966 : 4250;   // length of WALL 2 / WALL 4 (floor width)
final float ROOM_D = (VENUE == 1) ? 3206 : 4300;   // length of WALL 1 / WALL 3 (floor depth)
final float WALL_H = 1200;                         // wall height
final float MATRIX_W = ROOM_W + 2 * WALL_H;   // 6650
final float MATRIX_H = ROOM_D + 2 * WALL_H;   // 6700

final int MAIN_FACE = 3;     // main screen (central word + text input): 0 FLOOR, 1-4 WALL 1-4

// Output pixels per matrix unit. 1.0 = native 6650x6700 (venue).
// PC tests: 0.3. If the venue machine struggles, 0.5 and let PIXERA scale up.
float RENDER_SCALE = 0.5;   // sharp enough to judge the look on a laptop; 0.3 if it gets slow
// Resolution of the painted motif of each tile, relative to its size on WALL 1.
// ~3 keeps it sharp also when it is shown big on the main wall. Lower = faster, blurrier.
float TEXTURE_DETAIL = 3;

final int FLOOR = 0, W1 = 1, W2 = 2, W3 = 3, W4 = 4;   // surface ids (Room.pde)

// Outputs (Output.pde). The media matrix is always made; besides, one image per group
// of surfaces, side by side, upright, in this order. Examples:
//   {}                                    → only the media matrix (one image)
//   { {W1, W2, W3, W4, FLOOR} }           → one image, all surfaces in a row
//   { {W1, W2}, {W3, W4}, {FLOOR} }       → three images (2 + 2 + 1)
//   { {W1, W2}, {W3, W4, FLOOR} }         → two images (2 + 3)
//   { {W1}, {W2}, {W3}, {W4}, {FLOOR} }   → one image per surface
// IASLab default: one strip 16344 x 1200, FRONT | RIGHT | BACK | LEFT (going round the room,
// so every seam is a real corner). Ask the technicians which order / split Watchout expects;
// the four walls as separate images: { {W3}, {W4}, {W1}, {W2} }.
int[][] OUTPUT_GROUPS   = (VENUE == 1) ? new int[][] { {W3, W4, W1, W2} } : new int[][] {};
// How the output images leave Processing (Output.pde):
//   "none"   → not sent (preview only, or OUTPUT_WINDOWS)
//   "syphon" → macOS, one Syphon stream per output: "language_viz 1", "language_viz 2"…
//   "spout"  → Windows, one Spout sender per output, same names
// Needs the library installed and its import line enabled at the top of language_viz.pde.
String  OUTPUT_SEND     = "none";
boolean OUTPUT_WINDOWS  = false;   // also open each output image in its own window (copies through the CPU: much slower, ~14 fps with 3 outputs on a laptop)
int[]   OUTPUT_DISPLAYS = {};      // display for each window, full screen (1 = main, 2 = second...); 0 / missing = small window

// Preview window only — the output image is 'matrixOut' (Room.pde)
boolean FULLSCREEN = false;
int WINDOW_W = 1400, WINDOW_H = 900;
boolean showOutlines = true;   // wall/floor outlines in the preview (Ctrl+L), never in the output

// Size of the text input on the main wall (1.0 = original proportions)
float UI_SCALE = 1.0;
// Text input box: centred, about as wide as the tile, at 3/4 of the wall's height
float UI_WIDTH = 0.55;   // width, × wall height (≈ the tile on the main wall)
float UI_Y     = 0.72;   // top of the box, fraction of the wall height (0 = top, 1 = bottom)
// Darkness of the band behind the text input (0 = none, 100 = solid black)
float UI_BAR_ALPHA = 35;

// Poem: margin below the ceiling
float CEILING_MARGIN  = 250;    // figures turn back before the top of the walls

// ── TRENCADÍS MOSAIC (WALL 1) ───────────────────────────────
final long MOSAIC_SEED   = 1914;  // layout of the mural; change it → a different mural
int   MOSAIC_ROWS        = 5;     // wavy bands on WALL 1 (more rows = smaller tiles, more words fit)
float MOSAIC_CELL_MIN    = 0.9;   // cell width, in band heights
float MOSAIC_CELL_MAX    = 1.6;
float GROUT_WIDTH        = 1.2;   // half the gap between shards, matrix units (varies a little per shard)
float GROUT_H = 38, GROUT_S = 5, GROUT_B = 80;   // grout colour (HSB): light grey cement, only once set on WALL 1
float GROUT_SET_FRAMES   = 170;   // frames the grout takes to seep in and dry when a tile lands on WALL 1
// Relief and finish of the shards (Trencadis.pde)
float RELIEF             = 1.0;   // tilt shading, rounded rims, sunk grout (0 = flat)
float RIM_PX             = 2.2;   // width of the rounded rim of each shard, output pixels
float AO_PX              = 2.2;   // width of the shadow in the grout next to each shard, output pixels
float GLAZE              = 30;    // glaze highlight on the shards tilted towards the light (0 = matte)
float SCATTER            = 1.0;   // how far the pieces drift apart while travelling (0 = they travel as one tile)
float ASSEMBLE_DEPTH     = 9;     // how far behind WALL 3 the shards come from while assembling (× the camera distance)
float ASSEMBLE_SPREAD    = 3;     // how scattered the shards are when they start far away (× tile size)
// Time on the main wall (frames, 60 = 1 s)
float ASSEMBLE_FRAMES_MIN = 110;  // assembling, agency 7
float ASSEMBLE_FRAMES_MAX = 220;  // assembling, agency 1
float HOLD_FRAMES_MIN    = 45;    // still, once assembled, time_duration 1
float HOLD_FRAMES_MAX    = 240;   // still, once assembled, time_duration 7
// Travel: false = the pieces slide along the walls / floor (2D, looks right from
// anywhere); true = they fly through the air of the room (3D, perfect from the
// viewer's point, more distorted the further you are). Ctrl+D toggles it live.
boolean TRAVEL_3D        = false;
float VIEWER_HEIGHT      = WALL_H * ((VENUE == 1) ? 0.59 : 0.4);   // eye height of the audience: IASLab 1.6 m of 2.7 m projected
float DEPTH_3D           = 1.0;            // how far into the room the pieces fly (3D)
float HOLD_HEIGHT        = 0.45;  // size of the new tile on the main wall (fraction of its height)
float HOLD_Y             = 0.38;  // its centre, fraction of the wall height (leaves room for the text input below)
float HOLD_PANEL_ALPHA   = 72;    // dark see-through window behind the new tile (0 = none, 100 = black)
String  MOSAIC_FILE      = "mosaic.json";   // in data/
boolean MOSAIC_SAVE      = true;  // keep the mural between runs

// ── SOUND ───────────────────────────────────────────────────
final String MIDI_PORT = "processing (A)";
//final String MIDI_PORT = "Bus 1";
int CH_LEAD  = 1;

// ── TEST MODE ───────────────────────────────────────────────
// Ctrl+E toggles it. Words skip the LLM and get RANDOM parameters (shown on the
// main wall). Tiles placed in test mode are not saved: leaving test mode brings
// back the real mural from data/mosaic.json.
boolean TEST_MODE = false;

// ── LLM API CONFIG ───────────────────────────────────────────────────
final String API_KEY     = "";  // ← your key
final String MODEL       = "claude-haiku-4-5-20251001";
final String prompt_path = "prompts/haiku_art_system_prompt.md";
String SYSTEM_PROMPT;

// Central word parameters -> updated by JSONLoader
int pEmotion    = 1;
int pWordClass  = 1;
int pAbstract   = 4;
int pAgency     = 4;
int pOrganic    = 4;
int pPhenomenon = 1;
int pTime       = 4;
color pColorHex  = color(255, 165, 0);
String currentWord = "—";


// Poem system (small floating tiles)
boolean SHOW_POEM       = true; // false = no floating poem tiles (Ctrl+P toggles it live)
int MAX_POEM_WORDS      = 40;   // little shards floating at the same time (beyond that the oldest slowly fades)
int POEM_SPAWN_INTERVAL = 600;  // frames between poem words (60 = 1 s)
float POEM_TILE_SIZE    = 420;  // width of a poem tile, matrix units
float POEM_ALPHA        = 70;   // 0..100, so they stay behind the mural
float POEM_SPREAD        = 1.4;  // how wide the cloud opens (× tile size)
float POEM_EMERGE_DEPTH  = 14;   // how far behind the main wall it comes from
float POEM_EMERGE_FRAMES = 360;  // coming out of the depth (it already moves towards its spot)
float POEM_TRAVEL_FRAMES = 720;  // rest of the journey, opening more and more
float POEM_CLOSE_FRAMES  = 420;  // closing (after the word has gone)
float POEM_WORD_FRAMES   = 120;  // the open cloud stays still with its word in the middle (60 = 1 s); then the word goes down
float POEM_BIRTH_SCALE   = 0.25; // size of the pieces when they are born (they grow on the way)
float POEM_GROW_START    = 0.4;  // part of the journey they travel still small before growing (0..1)
float POEM_COLLAPSE_FRAMES = 300; // folding into one little shard
float POEM_MINI_SIZE     = 60;   // size of the little shard, matrix units
float POEM_FAR_SCALE     = 0.45; // size of the farthest poem words (nearest = 1): depth, sense of 3D
float POEM_SIZE_MIN      = 0.6;  // on top of the depth, each word is a bit smaller or bigger
float POEM_SIZE_MAX      = 1.3;
float POEM_MINI_SPEED     = 3.0;  // how fast the little shards wander the walls (units per frame)
float POEM_WORD_SPEED     = 1.2;  // how fast the words float on the floor
float POEM_DESCEND_FRAMES = 420;  // the word gliding down the wall to the floor

// ****************
// Shared utilities
// ****************

//Convert from HEX to HSB color mode
color parseHexColor(String hex) {
  hex = hex.trim();
  if (hex.startsWith("#")) hex = hex.substring(1);
  if (hex.length() != 6) return color(255, 165, 0);
  int r = unhex(hex.substring(0, 2));
  int g = unhex(hex.substring(2, 4));
  int b = unhex(hex.substring(4, 6));
  colorMode(RGB, 255);
  color rgb = color(r, g, b);
  colorMode(HSB, 360, 100, 100, 100);
  return color(hue(rgb), saturation(rgb), brightness(rgb));
}

// Lerp between two hues respecting circular 0-360 wrap
float lerpAngle(float a, float b, float amt) {
  float diff = b - a;
  if (diff >  180) diff -= 360;
  if (diff < -180) diff += 360;
  return (a + diff * amt + 360) % 360;
}
