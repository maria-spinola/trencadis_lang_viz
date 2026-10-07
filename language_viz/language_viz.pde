// ═══════════════════════════════════════════════════════════
// final_project_block1.pde  ←  MAIN SKETCH
// MDACT Project — 1st BLOCK Final Project
// ═══════════════════════════════════════════════════════════

int camMode = 3;
float smoothMX = 0, smoothMY = 0;
boolean isDragging = false;
float dragStartX, dragStartY;
float camRotH = 0, camRotV = 0;
boolean showUI     = true;    // text input on the main wall
boolean showTest   = false;   // calibration grid in the output (Ctrl+T)
int     viewMode   = 0;       // preview only: 0 = media matrix, 1..5 = FLOOR, WALL 1..4, then the outputs (Ctrl+V cycles)
boolean soundReady = false;

// ── OUTPUT TO PIXERA ──────────────────────────────────────────
// The whole media matrix is the image 'matrixOut' (Room.pde); other layouts
// (one image per surface, 2 + 2 + 1...) are set with OUTPUT_GROUPS in Config.pde.
// Sending them (windows, Syphon, Spout): see Output.pde.
// To send by Syphon / Spout (OUTPUT_SEND in Config.pde), install the library and remove
// the // before its line. Processing needs the import to load the library; leave the
// other one commented (Syphon only exists on macOS, Spout only on Windows).
// import codeanticode.syphon.*;   // OUTPUT_SEND = "syphon"  (macOS)
// import spout.*;                 // OUTPUT_SEND = "spout"   (Windows)

void settings() {
  if (FULLSCREEN) fullScreen(P3D);
  else            size(WINDOW_W, WINDOW_H, P3D);
  pixelDensity(1);   // keeps the output at exactly RENDER_SCALE: with 2 (Retina) every buffer, also the output, doubles
  smooth(4);   // antialiasing of the shard edges (2 = faster, 8 = smoother)
}

void setup() {
  colorMode(HSB, 360, 100, 100, 100);
  background(0);
  noCursor();
  noiseDetail(2, 0.5);
  hint(DISABLE_DEPTH_TEST);
  hint(ENABLE_STROKE_PURE);
  noiseSeed((int) MOSAIC_SEED);   // poem tiles wander the same way on every run
  setupRoom();    // Room.pde — walls + floor buffers and media matrix
  setupOutputs(); // Output.pde — output images / windows (OUTPUT_GROUPS)
  if (OUTPUT_GROUPS.length > 0) viewMode = faces.length + 1;   // preview the first output
  setupMosaic();  // Mosaic.pde — trencadís mural on WALL 1 (restores data/mosaic.json)
  setupWords();   // WordsSystem.pde
  setupLLM();     // ClaudeSketch.pde — carga system prompt
  loadJSONFromPath(jsonPath, false);   // last parameters, without adding a tile again
}

void draw() {
  // Sound init deferred to first frame (P3D + themidibus workaround)
  if (!soundReady) { 
    setupSoundEngine();
    soundReady = true; 
  }

  checkFileChanged();  // JSONLoader.pde
  updateLLM();         // ClaudeSketch.pde — procesa respuesta API
  updateCameraDrag();  // Room.pde — Ctrl+M mode
  updateWords();       // WordsSystem.pde — poem tiles
  updateMosaic();      // Mosaic.pde — word tiles assembling / travelling / landing
  renderFaces();       // Room.pde — draws each wall + floor (camera, words, text input)
  if (OUTPUT_GROUPS.length == 0 || viewMode == 0) composeMatrix();   // Room.pde — media matrix → matrixOut (only if used)
  composeOutputs();    // Output.pde — the output images, sent out
  drawPreview();       // Room.pde — shows it in this window
}

void mousePressed() {
  if (camMode == 5) { isDragging = true; dragStartX = mouseX; dragStartY = mouseY; }
}

void mouseReleased() { isDragging = false; }

void keyPressed(KeyEvent event) {
  //Keys + Ctrl/Cmd to avoid changes while writing words
  if (!event.isControlDown() && !event.isMetaDown()) {
    handleLLMKey();  // ClaudeSketch.pde — captura input de texto
    return;
  }
  if (keyCode == 'P') SHOW_POEM = !SHOW_POEM;
  if (keyCode == 'G') camMode = 4;
  if (keyCode == 'R') loadJSONFromPath(jsonPath);
  if (keyCode == 'M') camMode = 5;
  if (keyCode == '3') camMode = 3;
  if (keyCode == '2') camMode = 2;
  if (keyCode == 'V') viewMode = (viewMode + 1) % (faces.length + 1 + outImgs.size());
  if (keyCode == 'T') showTest = !showTest;
  if (keyCode == 'U') showUI = !showUI;
  if (keyCode == 'L') showOutlines = !showOutlines;
  if (keyCode == 'N') clearMosaic();   // empty the mural on WALL 1
  if (keyCode == 'E') toggleTestMode(); // random parameters, no LLM, nothing saved
  if (keyCode == 'D') TRAVEL_3D = !TRAVEL_3D;   // pieces travel along the walls (2D) or through the room (3D)
}

void dispose() { 
  disposeSoundEngine(); 
}
