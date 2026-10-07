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
void drawLLMInterface() {
  // Switch to 2D for the overlay
  hint(DISABLE_DEPTH_TEST);
  camera();
  noLights();

  // Input field background
  noStroke();
  fill(0, 0, 0, 180);
  rect(0, height - 90, width, 90);

  // Separator line
  stroke(60);
  strokeWeight(1);
  line(0, height - 80, width, height - 80);
  noStroke();

  // Last prompt echo
  if (lastPrompt.length() > 0) {
    fill(80);
    textSize(13);
    textAlign(LEFT, TOP);
    text("↳ " + lastPrompt, 40, height - 110);
  }

  // Response / error text — small strip above input
  if (displayText.length() > 0) {
    fill(210);
    textSize(13);
    textAlign(LEFT, CENTER);
    text(displayText, 40, height - 95, width - 80, 20);
  }

  // Prompt symbol
  fill(90);
  textSize(14);
  textAlign(LEFT, CENTER);
  text(">", 20, height - 46);

  // Input text + cursor
  fill(220);
  String displayed = inputText + (cursorVisible ? "█" : " ");
  text(displayed, 44, height - 46);

  // "thinking..." indicator
  if (isLoading) {
    fill(80, 180, 120);
    textSize(12);
    textAlign(RIGHT, CENTER);
    text("thinking...", width - 20, height - 46);
  }
}

// ── Called from main keyPressed() ────────────────────────────────
void handleLLMKey() {
  if (key == ENTER || key == RETURN) {
    String trimmed = inputText.trim();
    if (trimmed.length() > 0 && !isLoading) {
      lastPrompt  = trimmed;
      displayText = "";
      if (API_KEY.length() == 0) {
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
