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
}

// ── Called from main draw() ───────────────────────────────────────
void updateLLM() {
  if (responseRaw != null) parseResponse();
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

  // Switch to 2D for the overlay
  pg.hint(DISABLE_DEPTH_TEST);
  pg.perspective();
  pg.camera();
  pg.noLights();

  // Input field background
  pg.noStroke();
  if (UI_BAR_ALPHA > 0) {
    pg.fill(0, 0, 0, UI_BAR_ALPHA);
    pg.rect(x0, y0, bw, bh);
  }

  // Separator line
  pg.stroke(60);
  pg.strokeWeight(max(1, ui));
  pg.line(x0, y0 + 10 * ui, x1, y0 + 10 * ui);
  pg.noStroke();

  // Last prompt echo
  if (lastPrompt.length() > 0) {
    pg.fill(80);
    pg.textSize(13*ui);
    pg.textAlign(LEFT, BOTTOM);
    pg.text("↳ " + lastPrompt, x0 + 20*ui, y0 - 4*ui);
  }

  // Response / error text — small strip above the box
  if (displayText.length() > 0) {
    pg.fill(210);
    pg.textSize(13*ui);
    pg.textAlign(LEFT, BOTTOM);
    pg.text(displayText, x0 + 20*ui, y0 - 60*ui, bw - 40*ui, 38*ui);
  }

  // Prompt symbol
  pg.fill(90);
  pg.textSize(14*ui);
  pg.textAlign(LEFT, CENTER);
  pg.text(">", x0 + 20*ui, mid);

  // Input text + cursor
  pg.fill(220);
  String displayed = inputText + (cursorVisible ? "█" : " ");
  pg.text(displayed, x0 + 44*ui, mid);

  // Test mode badge
  if (TEST_MODE) {
    pg.fill(35, 90, 100);
    pg.textSize(13*ui);
    pg.textAlign(RIGHT, BOTTOM);
    pg.text("TEST MODE · not saved (Ctrl+E)", x1 - 20*ui, y0 - 4*ui);
  }

  // "thinking..." indicator
  if (isLoading) {
    pg.fill(80, 180, 120);
    pg.textSize(12*ui);
    pg.textAlign(RIGHT, CENTER);
    pg.text("thinking...", x1 - 20*ui, mid);
  }
}

// ── Called from main keyPressed() ────────────────────────────────
void handleLLMKey() {
  if (key == ENTER || key == RETURN) {
    String trimmed = inputText.trim();
    if (trimmed.length() > 0 && !isLoading) {
      lastPrompt  = trimmed;
      displayText = "";
      if (TEST_MODE) {
        generateTestWord(trimmed);     // utils.pde — random parameters
      } else if (API_KEY.length() == 0) {
        generateRandomWord(trimmed);
      } else {
        callClaude(trimmed);
      }
      inputText = "";
    }
  } else if (key == BACKSPACE) {
    if (inputText.length() > 0)
      inputText = inputText.substring(0, inputText.length() - 1);
  } else if (key == ESC) {
    key = 0;  // evita que ESC cierre el sketch
  } else if (key != CODED) {
    inputText += key;
  }
}
