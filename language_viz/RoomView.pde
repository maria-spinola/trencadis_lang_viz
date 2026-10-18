// ═══════════════════════════════════════════════════════════
// RoomView.pde
// Ctrl+I: see the installation as if standing inside the room.
// The preview window becomes a first-person view from the middle
// of the room at eye height: the four walls (and the floor, if the
// venue has one) at their real size and place, with the images
// they will receive. Drag the mouse or use the arrow keys to look
// around, mouse wheel to zoom. Only the preview: the output is the same.
//
// Ctrl+J simulates what projection does to the image, so contrast
// can be judged before going to the room:
//   - a projector never shows black: a little light always comes out (PROJ_BLACK)
//   - the walls light each other: a bright wall greys the opposite one (ROOM_BOUNCE)
//   - how bright the projectors are compared with a screen (PROJ_GAIN)
// ═══════════════════════════════════════════════════════════

boolean roomView = false;
boolean projSim = false;                             // Ctrl+J: off = the images exactly as they are sent
float roomYaw = 0, roomPitch = 0.05, roomFov = 55;   // 55° high ≈ what the eye takes in without turning
PVector roomPos;                                     // where the viewer stands (null = the centre, the sweet spot)   // looking at the main wall (WALL 3) to start with
float[] faceAvg = new float[5];                      // average brightness of each surface (0–1), for the bounce
float[][] faceCol = new float[5][3];                  // and its average colour
PGraphics avgBuf;

void toggleRoomView() {
  roomView = !roomView;
  roomPos = null;   // back to the centre
  println("Room view " + (roomView ? "ON — drag to look around, wheel to zoom, Ctrl+J projection" : "OFF"));
}

// Where the viewer looks: yaw 0 = the main wall
PVector roomLookDir() {
  PVector toMain = PVector.sub(faces[MAIN_FACE].toRoom(faces[MAIN_FACE].w / 2, faces[MAIN_FACE].h / 2), roomEye());
  float base = atan2(toMain.y, toMain.x);
  float a = base + roomYaw;
  return new PVector(cos(a) * cos(roomPitch), sin(a) * cos(roomPitch), sin(roomPitch));
}

PVector roomEye() { return roomPos != null ? roomPos.copy() : new PVector(ROOM_W / 2, ROOM_D / 2, VIEWER_HEIGHT); }

void drawRoomView() {
  background(hexColor(ROOM_VIEW_OUTSIDE));
  if (frameCount % 10 == 0) measureFaces();
  PVector eye = roomEye(), d = roomLookDir();
  hint(ENABLE_DEPTH_TEST);
  perspective(radians(roomFov), width / (float) height, 5, 40000);
  camera(eye.x, eye.y, eye.z, eye.x + d.x * 100, eye.y + d.y * 100, eye.z + d.z * 100, 0, 0, -1);   // z is up in the room
  noLights();
  noStroke();
  textureMode(NORMAL);

  float total = 0; int n = 0;
  for (Face f : faces) if (f.id != FLOOR || HAS_FLOOR) { total += faceAvg[f.id]; n++; }
  for (Face f : faces) {
    if (f.id == FLOOR && !HAS_FLOOR) continue;
    // light that falls on this surface from all the others
    float others = (n > 1) ? (total - faceAvg[f.id]) / (n - 1) : 0;
    float add = projSim ? PROJ_BLACK + ROOM_BOUNCE * others : 0;
    float gain = projSim ? PROJ_GAIN : 1;
    PVector a = f.toRoom(0, 0), b = f.toRoom(f.w, 0), c = f.toRoom(f.w, f.h), e = f.toRoom(0, f.h);
    beginShape(QUADS);
    texture(f.pg);
    tint(0, 0, 100 * min(1, gain));
    vertex(a.x, a.y, a.z, 0, 0); vertex(b.x, b.y, b.z, 1, 0); vertex(c.x, c.y, c.z, 1, 1); vertex(e.x, e.y, e.z, 0, 1);
    endShape();
    noTint();
    if (add > 0.002) {   // the light that greys it, added on top
      blendMode(ADD);
      fill(0, 0, 100 * min(1, add));
      beginShape(QUADS);
      vertex(a.x, a.y, a.z); vertex(b.x, b.y, b.z); vertex(c.x, c.y, c.z); vertex(e.x, e.y, e.z);
      endShape();
      blendMode(BLEND);
    }
  }
  // What isn't projected: the floor (if the venue has none), the strip above the image and the ceiling,
  // lit only by what bounces off the walls
  // (in a colour of their own, so the projected surfaces stand out — not part of the output)
  float bounce = projSim ? ROOM_BOUNCE * (n > 0 ? total / n : 0) : 0;
  float top = WALL_H + (ROOM_SHELL ? max(ROOM_EXTRA_H, WALL_H * ROOM_SHELL_TOP) : ROOM_EXTRA_H);
  shellFill(ROOM_VIEW_FLOOR, (projSim ? PROJ_BLACK * 0.3 : 0) + bounce * 0.5);
  if (!HAS_FLOOR) quad3(0, 0, 0, ROOM_W, 0, 0, ROOM_W, ROOM_D, 0, 0, ROOM_D, 0);
  if (ROOM_SHELL) drawRoomShell(top);
  else {
    shellFill(ROOM_VIEW_CEILING, bounce * 0.35);
    quad3(0, 0, top, ROOM_W, 0, top, ROOM_W, ROOM_D, top, 0, ROOM_D, top);
  }

  hint(DISABLE_DEPTH_TEST);

  // back to 2D for the text
  camera();
  perspective();
  fill(0, 0, 70);
  textSize(12);
  textAlign(LEFT, TOP);
  text(nf(frameRate, 0, 1) + " fps  ·  ROOM VIEW (Ctrl+I)  ·  drag / arrows: look  ·  right drag: walk" + (roomPos == null ? " (now at the centre)" : "")
       + "  ·  wheel: zoom " + round(roomFov) + "°"
       + "  ·  Ctrl+J projection " + (projSim ? "ON: black " + round(PROJ_BLACK * 100) + "%, bounce " + round(ROOM_BOUNCE * 100) + "%, gain " + nf(PROJ_GAIN, 0, 2) : "OFF"), 10, 10);
  text(llmStatus(), 10, 26);
  drawTravelMode();
  if (PREVIEW_INPUT) drawPreviewInput();
}

void quad3(float x1, float y1, float z1, float x2, float y2, float z2, float x3, float y3, float z3, float x4, float y4, float z4) {
  beginShape(QUADS);
  vertex(x1, y1, z1); vertex(x2, y2, z2); vertex(x3, y3, z3); vertex(x4, y4, z4);
  endShape();
}

// Average brightness of every surface, from a tiny copy (for the light bouncing between walls)
void measureFaces() {
  if (avgBuf == null) avgBuf = createGraphics(16, 8, P2D);
  for (Face f : faces) {
    if (f.id == FLOOR && !HAS_FLOOR) { faceAvg[f.id] = 0; continue; }
    avgBuf.beginDraw();
    avgBuf.image(f.pg, 0, 0, avgBuf.width, avgBuf.height);
    avgBuf.endDraw();
    avgBuf.loadPixels();
    float s = 0, cr = 0, cg = 0, cb = 0;
    for (int c : avgBuf.pixels) {
      float r = ((c >> 16) & 255) / 255.0, g = ((c >> 8) & 255) / 255.0, bl = (c & 255) / 255.0;
      s += r * 0.2126 + g * 0.7152 + bl * 0.0722; cr += r; cg += g; cb += bl;
    }
    int np = avgBuf.pixels.length;
    faceCol[f.id] = new float[] { cr / np, cg / np, cb / np };
    faceAvg[f.id] = s / avgBuf.pixels.length;
  }
}

// Mouse and keys while the room view is on: left drag looks around, right drag walks
// (up / down = forwards / backwards, sideways = step aside)
void roomDrag() {
  if (mouseButton == RIGHT) {
    PVector p = roomEye(), d = roomLookDir();
    float fx = d.x, fy = d.y, l = max(1e-4, sqrt(fx * fx + fy * fy));
    fx /= l; fy /= l;
    float step = 6;
    p.x += fx * (pmouseY - mouseY) * step + fy * (mouseX - pmouseX) * step;
    p.y += fy * (pmouseY - mouseY) * step - fx * (mouseX - pmouseX) * step;
    float m = 150;
    p.x = constrain(p.x, m, ROOM_W - m);
    p.y = constrain(p.y, m, ROOM_D - m);
    roomPos = p;
    return;
  }
  roomYaw   -= (mouseX - pmouseX) * 0.005;
  roomPitch  = constrain(roomPitch + (mouseY - pmouseY) * 0.004, -1.2, 1.2);
}

boolean roomKey() {
  if (!roomView || key != CODED) return false;
  if (keyCode == LEFT)  { roomYaw += 0.12; return true; }
  if (keyCode == RIGHT) { roomYaw -= 0.12; return true; }
  if (keyCode == UP)    { roomPitch = min(1.2, roomPitch + 0.08); return true; }
  if (keyCode == DOWN)  { roomPitch = max(-1.2, roomPitch - 0.08); return true; }
  return false;
}

void mouseWheel(processing.event.MouseEvent ev) {
  if (roomView) roomFov = constrain(roomFov + ev.getCount() * 3, 30, 120);
}

// Top right of the preview (normal and room view): how the pieces travel now
void drawTravelMode() {
  pushStyle();
  textSize(14);
  textAlign(RIGHT, TOP);
  String t = TRAVEL_3D ? "3D TRAVEL · camera rig at eye height" : "2D TRAVEL · flat on the walls";
  float w = textWidth(t) + 20;
  noStroke();
  fill(TRAVEL_3D ? color(200, 70, 60) : color(35, 80, 70));
  rect(width - 10 - w, 8, w, 24, 4);
  fill(0, 0, 100);
  text(t, width - 20, 12);
  textSize(10);
  fill(0, 0, 60);
  text("Ctrl+D switches", width - 20, 36);
  popStyle();
}

// A surface that isn't projected: its own colour, plus the light bouncing off the walls
void shellFill(String hex, float add) {
  int c = hexColor(hex);
  float r = ((c >> 16) & 255) / 255.0 + add, g = ((c >> 8) & 255) / 255.0 + add, b = (c & 255) / 255.0 + add;
  fill(0xFF000000 | (round(constrain(r, 0, 1) * 255) << 16) | (round(constrain(g, 0, 1) * 255) << 8) | round(constrain(b, 0, 1) * 255));
}

// The room around the projection (only in the room view): a plain ceiling and the strip of wall
// above the image, lit only by the light the projected surfaces throw on them — warmer and brighter
// near a bright wall, in its colour, fading to dark away from it. Not physically exact: enough to
// feel inside a room instead of in endless black.
float[] shellLight(float x, float y, float z) {
  float r = 0, g = 0, b = 0, side = min(ROOM_W, ROOM_D);
  int[] ws = { W1, W2, W3, W4, FLOOR };
  for (int w : ws) {
    if (w == FLOOR && !HAS_FLOOR) continue;
    float d = (w == W1) ? x : (w == W2) ? y : (w == W3) ? ROOM_W - x : (w == W4) ? ROOM_D - y : z;
    float k = faceAvg[w] * exp(-max(0, d) / (side * 0.28)) * (w == FLOOR ? 0.35 : 1);
    r += faceCol[w][0] * k; g += faceCol[w][1] * k; b += faceCol[w][2] * k;
  }
  float[] base = rgb01(ROOM_SHELL_COLOR);
  return new float[] { base[0] + r * ROOM_SHELL_BOUNCE, base[1] + g * ROOM_SHELL_BOUNCE, base[2] + b * ROOM_SHELL_BOUNCE };
}

void shellVertex(float x, float y, float z) {
  float[] c = shellLight(x, y, z);
  fill(0xFF000000 | (round(constrain(c[0], 0, 1) * 255) << 16) | (round(constrain(c[1], 0, 1) * 255) << 8) | round(constrain(c[2], 0, 1) * 255));
  vertex(x, y, z);
}

void drawRoomShell(float top) {
  int n = 14;
  noStroke();
  beginShape(QUADS);
  for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) {   // the ceiling
    float x0 = ROOM_W * i / n, x1 = ROOM_W * (i + 1) / n, y0 = ROOM_D * j / n, y1 = ROOM_D * (j + 1) / n;
    shellVertex(x0, y0, top); shellVertex(x1, y0, top); shellVertex(x1, y1, top); shellVertex(x0, y1, top);
  }
  for (int i = 0; i < n; i++) {                                // the strip of wall above the image, all round
    float a0 = i / (float) n, a1 = (i + 1) / (float) n;
    float[][] walls = { {0, ROOM_D, 0, 0}, {0, 0, ROOM_W, 0}, {ROOM_W, 0, ROOM_W, ROOM_D}, {ROOM_W, ROOM_D, 0, ROOM_D} };
    for (float[] w : walls) {
      float xa = lerp(w[0], w[2], a0), ya = lerp(w[1], w[3], a0), xb = lerp(w[0], w[2], a1), yb = lerp(w[1], w[3], a1);
      shellVertex(xa, ya, WALL_H); shellVertex(xb, yb, WALL_H); shellVertex(xb, yb, top); shellVertex(xa, ya, top);
    }
  }
  endShape();
}
