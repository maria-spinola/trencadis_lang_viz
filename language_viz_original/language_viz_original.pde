// ═══════════════════════════════════════════════════════════
// final_project_block1.pde  ←  MAIN SKETCH
// MDACT Project — 1st BLOCK Final Project
// ═══════════════════════════════════════════════════════════

int camMode = 3;
float smoothMX = 0, smoothMY = 0;
boolean isDragging = false;
float dragStartX, dragStartY;
float camRotH = 0, camRotV = 0;
boolean showPoem   = true;
boolean soundReady = false;

void settings() {
  //size(1200, 800, P3D);
  fullScreen(P3D);
  smooth(2);
}

void setup() {
  colorMode(HSB, 360, 100, 100, 100);
  background(0);
  noCursor();
  noiseDetail(2, 0.5);
  hint(DISABLE_DEPTH_TEST);
  hint(ENABLE_STROKE_PURE);
  setupWords();   // WordsSystem.pde
  setupLLM();     // ClaudeSketch.pde — carga system prompt
  loadJSONFromPath(jsonPath);
}

void draw() {
  // Sound init deferred to first frame (P3D + themidibus workaround)
  if (!soundReady) { 
    setupSoundEngine();
    soundReady = true; 
  }

  checkFileChanged();  // JSONLoader.pde
  updateLLM();         // ClaudeSketch.pde — procesa respuesta API
  t     += 0.006;
  glowT += 1;

  background(0);
  updateCamera();      // local function below
  updateWords();       // WordsSystem.pde
  displayWords();      // WordsSystem.pde
  drawLLMInterface();  // ClaudeSketch.pde — overlay 2D encima del 3D
}

void updateCamera() {
  switch (camMode) {
    case 2:
      camera(0, 0, 780, 0, 20, 0, 0, 1, 0);
      ortho(-width/2, width/2, -height/2, height/2);
      break;
    case 3:
      perspective();
      float a3 = frameCount * 0.0008;
      camera(sin(a3)*120, sin(frameCount*0.0005)*60, 780+cos(a3)*60, 0, 30, 0, 0, 1, 0);
      break;
    case 4:
      perspective();
      float a4 = frameCount * 0.003;
      camera(sin(a4)*780, sin(frameCount*0.0012)*100, cos(a4)*780, 0, 0, 0, 0, 1, 0);
      break;
    case 5:
      perspective();
      if (isDragging) {
        camRotH += (mouseX - dragStartX) * 0.005;
        camRotV  = constrain(camRotV + (mouseY - dragStartY) * 0.003, -PI/2.5, PI/2.5);
        dragStartX = mouseX;
        dragStartY = mouseY;
      }
      float d = 780;
      camera(sin(camRotH)*cos(camRotV)*d, sin(camRotV)*d,
             cos(camRotH)*cos(camRotV)*d, 0, 0, 0, 0, 1, 0);
      break;
  }
}

void mousePressed() {
  if (camMode == 5) { isDragging = true; dragStartX = mouseX; dragStartY = mouseY; }
}

void mouseReleased() { isDragging = false; }

void keyPressed(KeyEvent event) {
  handleLLMKey();  // ClaudeSketch.pde — captura input de texto primero
  
  //Keys + Ctrl to avoid changes while writing words
  if (event.isControlDown() || event.isMetaDown()) {
    if (key == 'p') showPoem = !showPoem;
    if (key == 'g') camMode = 4;
    if (key == 'r') loadJSONFromPath(jsonPath);
    if (key == 'm') camMode = 5;
    if (key == '3') camMode = 3;
    if (key == '2') camMode = 2;
  }
}

void dispose() { 
  disposeSoundEngine(); 
}
