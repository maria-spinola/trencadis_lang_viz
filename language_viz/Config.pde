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
float UI_SCALE = 2.2;   // text size on the main wall (1.0 = tiny letters, ~4 cm in the room)
boolean PREVIEW_INPUT = true;   // also show what you type, big, at the bottom of the preview window (never in the output)

// Room view (Ctrl+I, RoomView.pde): the preview as if standing inside the room. Ctrl+J simulates projection:
float PROJ_BLACK   = 0.02;   // light a projector gives on black (0.05 = 5 % of white; real rooms 2–8 %)
float ROOM_BOUNCE  = 0.08;   // light each wall receives back from the others (white walls of an immersive room: 15–35 %)
float PROJ_GAIN    = 1.0;    // how bright the projected white is compared with this screen
float ROOM_EXTRA_H = (VENUE == 1) ? WALL_H * (3.16 / 2.7 - 1) : 0;   // unprojected wall above the image (IASLab: 2.7 m of 3.16 m)

// Rich words are rewarded with a more complex tile (Trencadis.pde). raresa also sets the tile size (SIZE_*).
float RICH_SHARD_SIMPLE = 1.5;    // shard size at culturalitat 1: a few big shards
float RICH_SHARD_RICH   = 0.7;    // shard size at culturalitat 7: many small shards
float RICH_ACCENT       = 0.28;   // culturalitat 7: share of shards from other tiles, in contrasting glazes
float RICH_GOLD         = 0.14;   // raresa 7: share of golden lustre shards (from raresa 4)
// Text input box: centred, about as wide as the tile, at 3/4 of the wall's height
float UI_WIDTH = 0.55;   // width, × wall height (≈ the tile on the main wall)
float UI_Y     = 0.72;   // top of the box, fraction of the wall height (0 = top, 1 = bottom)
// Darkness of the band behind the text input (0 = none, 100 = solid black)
float UI_BAR_ALPHA = 35;

// Poem: margin below the ceiling
float CEILING_MARGIN  = 250;    // figures turn back before the top of the walls

// ── TRENCADÍS MOSAIC (WALL 1) ───────────────────────────────
final long MOSAIC_SEED   = 1914;  // layout of the mural; change it → a different mural
boolean MOSAIC_SIDES     = true;  // when WALL 1 is full, the mural grows on both side walls (back → front)
int   MOSAIC_ROWS        = 5;     // wavy bands on WALL 1 (more rows = smaller tiles, more words fit)
float MOSAIC_CELL_MIN    = 0.9;   // cell width, in band heights
float MOSAIC_CELL_MAX    = 1.6;
// Tile size from raresa: common words take half a cell, rare ones two cells joined
int   SIZE_SMALL_MAX     = 2;     // raresa up to this → half a cell
int   SIZE_BIG_MIN       = 6;     // raresa from this → two cells
float SPLIT_WIDE         = 1.25;  // cells wider than this (band heights) split left / right, narrower ones top / bottom
float RIBBON_SHARE       = 1.0;   // share of tiles with the dark ribbon along the top (1 = the bands are drawn whole)
float GROUT_WIDTH        = 1.5;   // half the gap between shards, matrix units (varies a little per shard)
// (grout colour: GROUT_COLOR in Colors.pde)
float GROUT_SET_FRAMES   = 170;   // frames the grout takes to seep in and dry when a tile lands on WALL 1
// Relief and finish of the shards (Trencadis.pde)
float RELIEF             = 1.0;   // tilt shading, rounded rims, sunk grout (0 = flat)
float RIM_PX             = 2.2;   // width of the rounded rim of each shard, output pixels
float AO_PX              = 2.2;   // width of the shadow in the grout next to each shard, output pixels
float GLAZE              = 30;    // glaze highlight on the shards tilted towards the light (0 = matte)

// ── Ceramic look (Ceramic.pde) — how real the trencadís looks. Colours: Colors.pde ──
boolean CERAMIC_BAKE   = true;    // each tile baked pixel by pixel as glazed ceramic in lime mortar (false = the old flat look)
float SHARD_TILT_DEG   = 7;       // how tilted the shards sit in the mortar (degrees): neighbours catch the light differently
float UNDULATION       = 1.0;     // the glaze is not quite flat: orange peel and pools (0 = flat as glass)
float GLOSS            = 0.45;    // reflection of the sky on the glaze (0 = matte)
float SPECULAR         = 0.7;     // bright highlight where a shard or its edge faces the light
float RIM_WIDTH        = 1.4;     // the rounded edge of each shard, tile units (1 unit ≈ 2 mm)
float RIM_BEND         = 0.9;     // how much that edge rolls over (catches light / goes dark)
float EDGE_ROUGH       = 1.4;     // broken edges are not straight: how ragged (units)
float CHIP_DEPTH       = 3.2;     // where the glaze flaked off the edge, the fired clay shows (units)
float PAINT_WOBBLE     = 0.7;     // painted motifs: hand-painted lines wobble a little (units)
float MARBLE_SHARE     = 0.35;    // share of plain glazed tiles with marbled glaze (jaspeado)
float RELIEF_TILE_SHARE       = 0.012;   // share of shards from moulded relief tiles (leaves and berries)
float RELIEF_TILE_SHARE_OTHER = 0.18;    // …among the shards from other tiles (very Catalan words have more)
float RELIEF_DEPTH     = 7;       // how deep those reliefs are (units)
float GROUT_IRREGULAR  = 1.0;     // the joints are uneven: each edge of a shard at its own distance (0 = even)
float AO_STRENGTH      = 0.38;    // the mortar is darker right against the shards (they stand proud)
float AO_RADIUS        = 1.3;     // …over this distance (units)
float CONTACT_SHADOW   = 0.32;    // short shadow of each shard on the mortar, away from the light
float SHADOW_LEN       = 1.1;     // …its length (units)
float WHITE_SHARE      = 0.02;    // share of plain white crockery shards (less white = more contrast)
float CUT_WOBBLE       = 0.16;    // the cracks bend at odd angles (× shard size; 0 = straight cracks)
boolean GLASS_BOTTLES  = false;   // round bottle bottoms in some glass shards (she found them like eyes)
float SHARD_MIN        = 0.16;    // smallest shard, × the usual shard size² (bigger = never small pieces)
float CRACKLE_SHARE    = 0.3;     // share of plain glazed shards with a crackled glaze (craquelure)
float GLASS_SHARE      = 0.14;    // raresa 7: share of glass shards (from raresa 5); some are round bottle bottoms
float BAKE_MAX_PX      = 1400;

// ── The journey and the moments (Mosaic.pde, Moments.pde) ──
float CHUNK_SHARDS     = 6;       // the tile breaks into chunks of about this many shards (bigger = fewer, bigger chunks)
float BURST            = 0.9;     // how far the chunks are thrown out when the tile breaks (× its radius)
float CHUNK_TILT       = 0.75;    // how much the chunks tilt in perspective in the air (radians; never show their back)
float CHUNK_GROW       = 0.12;    // …how much bigger they look mid-flight (closer to us)
float CHUNK_THICK      = 6;       // …their thickness, the fired clay edge (units)
float CHUNK_SHADOW     = 0.5;     // …the soft shadow they cast on the wall behind them
float CHUNK_SHADOW_DIST = 38;     // …how far from them it falls at mid-flight (units)
int   SPECIAL_MIN      = 6;       // raresa or culturalitat from this: a special word
float SPECIAL_SLOW     = 1.5;     // …it assembles and stays this much slower
float SPECIAL_SHEEN    = 0.55;    // …with a golden reflection sweeping over it
int   LAND_GLOW_FRAMES = 420;     // a tile that settles in the mural lights up, its word beside it (frames)
int   AGAIN_GLOW_FRAMES = 480;    // a word typed again: its older tiles in the mural pulse (frames)
float MARK_GLOW        = 0.45;    // how bright that light is
float MURAL_SHEEN      = 0.5;     // the slow light sweeping over the mural (0 = none)
int   SWEEP_FRAMES     = 900;     // …how long it takes to cross WALL 4, WALL 1, WALL 2 (60 = 1 s)
int   SWEEP_PAUSE      = 1500;    // …and the pause before the next one
int   CELEBRATE_FRAMES = 600;     // when the mural is full: it glows and a chord plays (frames)
int   VERSE_EVERY      = 60 * 240;   // a verse of the poem forms on the floor every … frames (0 = never)
int   VERSE_FIRST      = 60 * 60;    // …the first time after this
int   VERSE_HOLD       = 60 * 12;    // …and stays this long once complete    // largest baked image side (memory)
float BAKE_DETAIL_MURAL = 0.4;    // image detail of the tiles restored into the mural at start (× TEXTURE_DETAIL)
float BAKE_DETAIL_POEM  = 0.4;    // image detail of the poem tiles
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
float HOLD_Y             = 0.33;
float THINK_ALPHA        = 55;    // the shards turning while the model thinks: how opaque (0–100)
boolean TYPED_WORDS_TO_FLOOR = true;   // the visitors' words also go down to the floor and float with the poem's  // its centre, fraction of the wall height (leaves room for the text input below)
float HOLD_PANEL_ALPHA   = 72;    // dark see-through window behind the new tile (0 = none, 100 = black)
String  MOSAIC_FILE      = "mosaic.json";   // in data/
boolean MOSAIC_SAVE      = true;  // keep the mural between runs

// ── SOUND ───────────────────────────────────────────────────
final String MIDI_PORT = "processing (A)";
//final String MIDI_PORT = "Bus 1";
int CH_LEAD  = 1;

// ── TEST MODE ───────────────────────────────────────────────
// Ctrl+E toggles it. Words get their real analysis (cache or LLM), shown category
// by category on the main wall. Tiles placed in test mode are not saved: leaving
// test mode brings back the real mural from data/mosaic.json.
boolean TEST_MODE = false;
boolean TEST_RANDOM = false;   // test mode with random parameters instead of the real analysis of the word

// ── LLM CONFIG ──────────────────────────────────────────────────────
// Which model analyses the words:
//   "ollama" → local model (LOCAL_ENGINE) and / or Ollama Cloud, as set by LLM_MODE (default)
//   "claude" → Anthropic API (needs API_KEY)
final String LLM_PROVIDER = "ollama";
// Where the model runs:
//   "local" → on this computer (LOCAL_ENGINE; setup_mac.command / setup_windows.bat install it)
//   "cloud" → Ollama Cloud (needs an API key: data/ollama_key.txt, never commit it)
//   "auto"  → local; if it doesn't answer, the cloud; if there's no network either,
//             parameters from the word itself (local filter only) — it never stops
// Ctrl+O switches it while running: auto → cloud → local (shown in the preview window).
volatile String LLM_MODE        = "auto";
// The local model:
//   "llamacpp" → Salamandra 7B Instruct 2606 (BSC, trained on Catalan) on llama.cpp's llama-server,
//                started by the sketch (LocalLLM.pde). BSC advises against running it with Ollama.
//   "ollama"   → OLLAMA_MODEL_LOCAL on a local Ollama
final String LOCAL_ENGINE       = "llamacpp";
boolean LLAMA_AUTOSTART  = true;            // start llama-server with the sketch and stop it on exit (one already running is reused)
String  LLAMA_SERVER     = "llama-server";  // the program: found on the PATH, in /opt/homebrew/bin, /usr/local/bin or winget's folder; or a full path
String  LLAMA_MODEL_FILE = "models/salamandra-7b-instruct-2606.i1-Q4_K_M.gguf";   // in the sketch folder (not in git: setup_mac.command downloads it)
int     LLAMA_PORT       = 8091;
int     LLAMA_CTX        = 8192;            // context tokens: instructions + examples (~5k) + word + answer. More = more memory
float   LLAMA_START_S    = 90;              // how long to wait for the server to load the model (also how long a word waits for it)
// Before asking the model, look the word up in the Catalan Wiktionary (Viquidiccionari) and
// send the model its definition: the models don't know many Catalan words. Needs internet;
// without it the model decides alone.
boolean USE_DICTIONARY = true;
String  DICT_URL       = "https://ca.wiktionary.org/w/api.php";
final String OLLAMA_URL_LOCAL   = "http://localhost:11434/api/chat";
final String OLLAMA_URL_CLOUD   = "https://ollama.com/api/chat";   // Authorization: Bearer <key>
final String OLLAMA_MODEL_LOCAL = "gemma3:4b";   // only with LOCAL_ENGINE "ollama"; "gemma3:12b" if the computer is powerful
final String OLLAMA_MODEL_CLOUD = "gemma4:31b";  // gemma3 isn't offered in the cloud (Oct 2026); same family, bigger.
                                                 // Alternative: "gpt-oss:20b". List: https://ollama.com/api/tags
String OLLAMA_API_KEY = "";   // leave empty here: it's read from data/ollama_key.txt (ignored by git)
final String API_KEY     = "";  // ← your key (only for LLM_PROVIDER "claude"; never commit it)
final String MODEL       = "claude-haiku-4-5-20251001";
final String prompt_path = "prompts/catala_art_system_prompt.md";   // (old English prompt: prompts/haiku_art_system_prompt.md)
String SYSTEM_PROMPT;

// Only ONE word in CATALAN is accepted (CatalanLLM.pde)
int    MAX_WORD_LENGTH   = 30;
String MSG_ONE_WORD      = "Escriu només una paraula en català";
String MSG_NOT_CATALAN   = "Aquesta paraula no és catalana";
String MSG_TOO_LONG      = "Paraula massa llarga";
String MSG_NO_LLM        = "";       // shown when the model doesn't answer (empty: nothing on the wall, only the console)
String MSG_DID_YOU_MEAN  = "Volies dir «%s»?";
String MSG_RARE          = "✦ Paraula rara ✦";            // special words (raresa / culturalitat ≥ SPECIAL_MIN)
String MSG_CATALAN       = "✦ Molt catalana ✦";
String MSG_RARE_CATALAN  = "✦ Rara i molt catalana ✦";
String MSG_INVITE        = "Escriu una paraula en català";   // in the empty text box   // shown when a missing / wrong accent is corrected
int    MSG_FRAMES        = 240;      // how long a message stays on the main wall (60 = 1 s)
boolean USE_LEXICON_CACHE = true;    // remember each word's answer in data/lexicon_cache.json
String LEXICON_CACHE_FILE = "lexicon_cache.json";
// raresa is measured, not guessed: how often the word appears in Catalan texts (wordfreq).
// Zipf scale: 5.8 casa · 4.6 finestra · 4.1 tristesa · 3.1 pessigolles · 2.8 espardenya · 2.2 xiuxiuejar
boolean USE_WORD_FREQ = true;
String WORD_FREQ_FILE = "catalan_freq.tsv";
// Missing or wrong accents are corrected from the same table ("cafe" → "cafè"): only when the
// accented form is at least ACCENT_FIX_GAP zipf more common (×25), so "mes", "te", "mon" stay
boolean USE_ACCENT_FIX = true;
boolean DEBUG_KEYS = false;   // print every key in the console (to see what an accent key sends)
float ACCENT_FIX_GAP = 1.4;
float ACCENT_FIX_GAP_WRONG = 0.8;   // the same for a rare word typed with an accent ("mès" → "més"): a wrong accent
float ACCENT_WRONG_MAX = 3.0;       // a word typed with an accent is never corrected from this zipf on: pèl, fóra, vós, sòl are words
float ACCENT_FIX_MIN = 2.0;   // the correction itself must be at least this common
float[] RARESA_ZIPF = { 5.0, 4.5, 4.0, 3.5, 3.0, 2.5 };   // zipf at or above → raresa 1, 2, 3, 4, 5, 6; below → 7

// Central word parameters -> updated by JSONLoader
int pEmotion    = 1;
int pWordClass  = 1;
int pAbstract   = 4;
int pAgency     = 4;
int pOrganic    = 4;
int pPhenomenon = 1;
int pTime       = 4;
int pCultura    = 1;   // culturalitat 1–7: how Catalan the word is  → shards from other tiles (RICH_ACCENT)
int pRaresa     = 1;   // raresa 1–7: how rare the word is in Catalan → golden lustre shards (RICH_GOLD)
color pColorHex  = color(255, 165, 0);
String currentWord = "—";


// Poem system (small floating tiles)
boolean SHOW_POEM       = true; // false = no floating poem tiles (Ctrl+P toggles it live)
int MAX_POEM_WORDS      = 200;   // little shards wandering at the same time (beyond that the oldest shard fades; its word stays)
int MAX_FLOOR_WORDS     = 400;  // words floating on the floor (repeats included); only beyond that the oldest fades
int POEM_SPAWN_INTERVAL = 600;  // frames between poem words (60 = 1 s)
float POEM_TILE_SIZE    = 420;  // width of a poem tile, matrix units
float POEM_ALPHA        = 100;  // 0..100: fully opaque (only the fades in and out are see-through)
float POEM_SPREAD        = 1.4;  // how wide the cloud opens (× tile size)
float POEM_EMERGE_DEPTH  = 14;   // how far behind the main wall it comes from
float POEM_EMERGE_FRAMES = 360;  // coming out of the depth (it already moves towards its spot)
float POEM_TRAVEL_FRAMES = 720;  // rest of the journey, opening more and more
float POEM_CLOSE_FRAMES  = 420;  // closing (after the word has gone)
float POEM_WORD_FRAMES   = 120;  // the open cloud stays still with its word in the middle (60 = 1 s); then the word goes down
float POEM_BIRTH_SCALE   = 0.25; // size of the pieces when they are born (they grow on the way)
float POEM_GROW_START    = 0.4;  // part of the journey they travel still small before growing (0..1)
float POEM_COLLAPSE_FRAMES = 300; // folding into one little shard
float POEM_VANISH_PART   = 0.45; // first part of it: the other pieces vanish one by one; then the kept one shrinks and turns
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
