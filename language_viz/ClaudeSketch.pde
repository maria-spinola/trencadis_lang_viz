// ════════════════════════════════════════════════════════════════
// ClaudeSketch.pde
// LLM interface — variables, drawing functions and API call.
// setup/draw/keyPressed live in final_project_block1.pde
// ════════════════════════════════════════════════════════════════

import java.net.URI;
import java.net.http.*;

// ── STATE ─────────────────────────────────────────────────────────
volatile String responseRaw = null;
volatile boolean isLoading  = false;
String inputText   = "";
String displayText = "";
String lastPrompt  = "";

// ── CURSOR BLINK ──────────────────────────────────────────────────
int     cursorTimer   = 0;
boolean cursorVisible = true;

// ── Called from main setup() ──────────────────────────────────────
void setupLLM() {
  SYSTEM_PROMPT = loadSystemPrompt(prompt_path);
  loadLexicon();   // CatalanLLM.pde
  loadWordFreq();
  loadLocalDictionary();   // CatalanLLM.pde: the Viquidiccionari on disk (for no internet)
  startNetWatch();   // CatalanLLM.pde: offline, words go straight to the local model
  if (LLM_PROVIDER.equals("ollama")) startLlamaServer();   // LocalLLM.pde: local model (only with LOCAL_ENGINE "llamacpp")
}

// ── Called from main draw() ───────────────────────────────────────
// Words typed while another is still being analysed or forming on the main wall wait their turn: each
// goes as soon as the one before it has left the wall (its flight begun)
ArrayList<String> wordQueue = new ArrayList<String>();
// A word can be written now: nothing else on its way (the box only invites when it can take one)
boolean wordReady() { return !wordBusy() && wordQueue.size() == 0; }

boolean wordBusy() {
  if (isLoading || fxActive() || fxLandPending) return true;   // (a moment of the walls playing, or about to: the word waits for it)
  for (TileFlight fl : flights) if (fl.state == FLIGHT_HOLD) return true;
  return revealAlpha() > 0.01 && revealEnd < 0;   // (the word is up and its tile not yet made)
}

void updateLLM() {
  if (responseRaw != null) parseResponse();
  if (wordQueue.size() > 0 && !wordBusy()) submitWord(wordQueue.remove(0));
  if (msgUntil > 0 && frameCount > msgUntil) { displayText = ""; msgUntil = 0; }
  cursorTimer++;
  if (cursorTimer >= 30) { cursorVisible = !cursorVisible; cursorTimer = 0; }
}

// ── Draws the input field overlay in 2D on top of the 3D scene ───
// Drawn into the main surface buffer (Room.pde), in its pixels.
void drawLLMInterface(PGraphics pg) {
  float W  = pg.width, H = pg.height;
  float ui = H / 900.0 * UI_SCALE;   // layout was designed for a 900 px tall screen

  // Centred box, about as wide as the tile, at 3/4 of the height
  float bw = min(W, H * UI_WIDTH);
  float bh = 90 * ui;
  float x0 = (W - bw) / 2, x1 = x0 + bw;
  float y0 = H * UI_Y;
  float mid = y0 + bh * 0.5 + 4 * ui;   // baseline of the input line

  // The same typeface as the words on the floor (Colors.pde); made once at its biggest size
  if (uiFont == null) uiFont = createFont(TEXT_FONT, max(12, round(14 * ui)));   // made at the size the typed word is seen at: crisp
  pg.textFont(uiFont);

  // Switch to 2D for the overlay
  pg.hint(DISABLE_DEPTH_TEST);
  pg.perspective();
  pg.camera();
  pg.noLights();

  // The box steps aside while a word is on the wall (its big word, its tile forming) or the room can't
  // take one yet (a journey, a moment of the walls), and comes back once a word can be written; it stays
  // while someone is typing, and with a word already sent that waits its turn (dimmed, until it is taken)
  boolean wordOnWall = isLoading || revealAlpha() > 0.01;
  for (TileFlight fl : flights) wordOnWall |= fl.shardsOnMainWall();   // until the last of its shards has flown away
  String waiting = wordQueue.size() > 0 ? wordQueue.get(0) : null;
  boolean showBox = inputText.length() > 0 || waiting != null || (wordReady() && !wordOnWall);
  uiK = lerp(uiK, showBox ? 1 : 0, showBox ? 0.05 : 0.25);

  // Input field background
  pg.noStroke();
  if (UI_BAR_ALPHA > 0 && uiK > 0.01) {
    pg.fill(hexColor(UI_BAR_COLOR), UI_BAR_ALPHA * uiK);
    pg.rect(x0, y0, bw, bh);
  }

  boolean onStone = backdropMode() == 2;   // on the stone the text is lighter and stronger, to stand out

  // Messages (rejections, "Volies dir…?", "✦ Paraula rara ✦"): small, centred under the field
  if (displayText.length() > 0) {
    pg.fill(hexColor(onStone ? UI_STONE_TEXT_COLOR : UI_MESSAGE_COLOR));
    pg.textSize(13*ui);
    pg.textAlign(CENTER, TOP);
    pg.text(displayText, W / 2, y0 + bh * 0.82);
  }

  // The field: centred; what is typed, or an invitation when it's empty; a cursor that breathes
  float breath = 0.5 + 0.5 * sin(millis() / 1000.0 * TWO_PI * 0.6);
  pg.textSize(14*ui);
  pg.textAlign(CENTER, CENTER);
  boolean queued = waiting != null && inputText.length() == 0;   // sent, waiting its turn: shown, breathing, no cursor
  boolean empty = inputText.length() == 0 && !queued;
  String shown = queued ? waiting : empty ? MSG_INVITE + "…" : inputText;
  int inputCol = hexColor(onStone ? UI_STONE_TEXT_COLOR : UI_INPUT_COLOR);
  pg.fill(inputCol, (empty ? (onStone ? 55 + 20 * breath : 30 + 18 * breath) : queued ? 55 + 30 * breath : 100) * uiK);
  if (!(empty && isLoading) && uiK > 0.01) pg.text(shown, W / 2, mid);
  float cxp = W / 2 + (empty ? -pg.textWidth(shown) / 2 - 8 * ui : pg.textWidth(shown) / 2 + 3 * ui);
  pg.noStroke();
  pg.fill(inputCol, (25 + 75 * breath) * uiK);
  if (uiK > 0.01 && !queued) pg.rect(cxp, mid - 9 * ui, max(1.5, 1.6 * ui), 18 * ui);

  // Test mode badge
  if (TEST_MODE) {
    pg.fill(hexColor(UI_TEST_COLOR));
    pg.textSize(13*ui);
    pg.textAlign(RIGHT, TOP);
    pg.text("TEST MODE · not saved (Ctrl+E)", x1 - 20*ui, y0 + bh + 22*ui);
  }

  // While the model thinks: a few shards turning where the tile will appear ("something is being made")
  if (revealAlpha() < 0.01) drawThinking(pg, W / 2, holdCentreY(), H);   // (the big word itself is the wait)

  // Test mode: the analysis of the last word, category by category, on the left of the wall
  if (TEST_MODE && lastAnalysis.length > 0) {
    if (pg.textFont == null) pg.textSize(13 * ui);   // make the default font exist, to put it back afterwards
    PFont prev = pg.textFont;
    float ts = min(13 * ui, W * 0.3 / (50 * 0.6)), lh = ts * 1.35;
    if (wallMonoFont == null) wallMonoFont = createFont("Monospaced", round(ts));
    float px = W * 0.03, py = H * 0.1;
    pg.noStroke();
    pg.fill(0, 0, 0, 70);
    pg.rect(px - ts, py - ts, W * 0.3 + 2 * ts, lh * lastAnalysis.length + 2 * ts);
    pg.textFont(wallMonoFont);
    pg.textSize(ts);
    pg.textAlign(LEFT, TOP);
    pg.fill(0, 0, 90);
    for (int i = 0; i < lastAnalysis.length; i++) pg.text(lastAnalysis[i], px, py + i * lh);
    pg.textFont(prev);
  }
}

float uiK = 1;        // how visible the text box is (it steps aside while a word is on the wall)
PFont wallMonoFont;   // fixed size: the analysis panel on the wall (test mode)
PFont uiFont;         // the text box's typeface (TEXT_FONT)

// ── Called from main keyPressed() ────────────────────────────────
// Only one word in Catalan: spaces and characters outside the Catalan alphabet can't be typed
void handleLLMKey(KeyEvent e) {
  if (key == ESC) { key = 0; return; }   // (ESC would close the sketch)
  // Only when a word can be taken (or one is being typed already): otherwise the box isn't there, and
  // what was typed would vanish into a queue nobody sees
  if (inputText.length() == 0 && !wordReady()) { pendingAccent = 0; return; }
  if (key == ENTER || key == RETURN) {
    if (inputText.trim().length() > 0) {
      if (wordBusy()) { if (wordQueue.size() < WORD_QUEUE_MAX) wordQueue.add(inputText); }   // it waits its turn
      else submitWord(inputText);   // CatalanLLM.pde: filters, cache, LLM
      inputText = "";
    }
    pendingAccent = 0;
  } else if (key == BACKSPACE) {
    if (inputText.length() > 0)
      inputText = inputText.substring(0, inputText.length() - 1);
    pendingAccent = 0;
  } else if (key == ESC) {
    key = 0;  // evita que ESC cierre el sketch
  } else if (key == CODED || key == 0 || key == 0xFFFF) {
    // Dead accent keys that the window doesn't compose arrive without a character: take them
    // by key (Spanish / Catalan keyboard: ` next to P, ´ next to Ñ; with Shift: ^ and ¨)
    char acc = deadAccent(keyCode, e != null && e.isShiftDown());
    if (acc != 0) pendingAccent = acc;
    else if (DEBUG_KEYS) println("Key without a character: keyCode " + keyCode + (e != null && e.isShiftDown() ? " + Shift" : ""));
  } else {
    // accents typed as a separate key first (dead keys that don't compose): ` ´ ' ¨ "
    if (DEBUG_KEYS) println("Key: '" + key + "' (" + (int) key + ") keyCode " + keyCode);
    if (key == '`' || key == '´' || key == '\'' || key == '¨' || key == '"') { pendingAccent = key; return; }
    if (pendingAccent != 0) {
      String c = composeAccent(pendingAccent, key);
      pendingAccent = 0;
      if (c != null) { if (inputText.length() < MAX_WORD_LENGTH) inputText += c; return; }
    }
    if (typable(key) && inputText.length() < MAX_WORD_LENGTH) inputText += key;
  }

  soundKey();   // SoundEngine.pde
}

// ── While the model thinks: a few real trencadís shards turning, see-through ──
// Seven shards of a freshly broken tile (the same glazed, relief shards as the mural) orbit
// slowly where the tile will appear and turn over on themselves, half transparent, as if the
// tile were being put together. A new tile each time; fades in and out.
float thinkA = 0;
TrencadisTile thinkTile;
IntList thinkIdx = new IntList();

void drawThinking(PGraphics pg, float cx, float cy, float H) {
  thinkA = lerp(thinkA, isLoading ? THINK_ALPHA : 0, 0.06);
  if (thinkA < 0.5) { thinkTile = null; return; }
  if (thinkTile == null) makeThinkTile();
  float t = millis() / 1000.0, R = H * 0.075, s = H * 0.032;
  pg.pushStyle();
  pg.noStroke();
  pg.textureMode(NORMAL);
  for (int k = 0; k < thinkIdx.size(); k++) {
    Piece p = thinkTile.pieces.get(thinkIdx.get(k));
    Random r = new Random(9100 + k);                   // each shard its own orbit and pace
    float a  = TWO_PI * k / thinkIdx.size() + t * (0.25 + r.nextFloat() * 0.2) * (k % 2 == 0 ? 1 : -1);
    float rr = R * (0.6 + 0.4 * r.nextFloat()) * (1 + 0.1 * sin(t * 1.1 + k));   // breathing in and out
    pg.pushMatrix();
    pg.translate(cx + cos(a) * rr * 1.5, cy + sin(a) * rr);
    pg.rotate(t * (0.4 + 0.5 * r.nextFloat()) * (k % 3 == 0 ? -1 : 1) + k);
    float flip = cos(t * (0.8 + 0.6 * r.nextFloat()) + k);   // turning over on itself
    float sc = s / max(1, sqrt(p.area));
    pg.scale(sc * (0.25 + 0.75 * abs(flip)), sc);
    IntList one = new IntList(); one.append(thinkIdx.get(k));
    thinkTile.drawPieces(pg, thinkA, one, p.cx, p.cy);
    pg.popMatrix();
  }
  pg.popStyle();
}

// A small tile broken like the others; its seven biggest shards are used
void makeThinkTile() {
  long seed = millis() + frameCount * 7919L;
  Random r = new Random(seed);
  color col = parseHexColor(emotionHex(1 + r.nextInt(7), 0, 70, 80));
  thinkTile = new TrencadisTile(seed, col, 4, 4, 1 + r.nextInt(7), 1, freePatch(r, 100, 80), -1);
  final ArrayList<Piece> ps = thinkTile.pieces;
  Integer[] order = new Integer[ps.size()];
  for (int i = 0; i < order.length; i++) order[i] = i;
  java.util.Arrays.sort(order, (x, y) -> Float.compare(ps.get(y).area, ps.get(x).area));
  thinkIdx = new IntList();
  for (int i = 0; i < min(7, order.length); i++) thinkIdx.append(order[i]);
}

// keyCode of a dead accent key → the accent, or 0. Java's dead-key codes, and the keys where the
// accents are on Spanish / Catalan keyboards (US positions [ and ')
char deadAccent(int kc, boolean shift) {
  if (kc == 128) return '`';                       // VK_DEAD_GRAVE
  if (kc == 129) return '´';                       // VK_DEAD_ACUTE
  if (kc == 135) return '¨';                       // VK_DEAD_DIAERESIS
  if (kc == 91 || kc == 186) return shift ? 0 : '`';     // [ position: ` (Shift: ^, not used in Catalan)
  if (kc == 222 || kc == 39) return shift ? '¨' : '´';   // ' position: ´ (Shift: ¨)
  return 0;
}
