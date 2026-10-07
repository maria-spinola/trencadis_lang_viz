// ═══════════════════════════════════════════════════════════
// Room.pde
// Immersive room: 4 walls + floor are rendered as 5 independent
// images and packed into ONE output image laid out exactly like
// the venue's MEDIA MATRIX (unfolded box):
//
//              ┌──────────┐
//              │  WALL 2  │
//   ┌──────────┼──────────┼──────────┐
//   │  WALL 1  │  FLOOR   │  WALL 3  │   ← WALL 3 = main screen
//   └──────────┼──────────┼──────────┘
//              │  WALL 4  │
//              └──────────┘
//
// Everything is measured in MEDIA MATRIX units (see Config.pde),
// so the same code works at any RENDER_SCALE.
//
// 3D room coordinates:
//   X: WALL 1 → WALL 3   (0..ROOM_W)
//   Y: WALL 2 → WALL 4   (0..ROOM_D)
//   Z: floor  → ceiling  (0..WALL_H)
// ═══════════════════════════════════════════════════════════

// (surface ids FLOOR, W1..W4 are declared in Config.pde)
Face[] faces = new Face[5];
PGraphics matrixOut;   // the full media matrix → send this to PIXERA
PFont testFont;        // own font so it doesn't share glyph textures with the text input

void setupRoom() {
  // Geometry. Each surface is seen upright from inside the room: u → right, v → down.
  //                     id     name      width   height  origin (u=0, v=0)                   u axis                  v axis
  faces[FLOOR] = new Face(FLOOR, "FLOOR",  ROOM_W, ROOM_D, new PVector(0,      0,      0),      new PVector( 1,  0, 0), new PVector(0, 1,  0));
  faces[W1]    = new Face(W1,    "WALL 1", ROOM_D, WALL_H, new PVector(0,      ROOM_D, WALL_H), new PVector( 0, -1, 0), new PVector(0, 0, -1));
  faces[W2]    = new Face(W2,    "WALL 2", ROOM_W, WALL_H, new PVector(0,      0,      WALL_H), new PVector( 1,  0, 0), new PVector(0, 0, -1));
  faces[W3]    = new Face(W3,    "WALL 3", ROOM_D, WALL_H, new PVector(ROOM_W, 0,      WALL_H), new PVector( 0,  1, 0), new PVector(0, 0, -1));
  faces[W4]    = new Face(W4,    "WALL 4", ROOM_W, WALL_H, new PVector(ROOM_W, ROOM_D, WALL_H), new PVector(-1,  0, 0), new PVector(0, 0, -1));

  // Placement in the MEDIA MATRIX: top-left corner + rotation (degrees) of the upright image.
  // Walls touch the floor with their bottom edge. If a wall looks rotated in PIXERA,
  // change only its rotation here (0, 90, 180, -90) — use Ctrl+T to check.
  faces[FLOOR].place(WALL_H,          WALL_H,            0);
  faces[W1]   .place(0,               WALL_H,          -90);
  faces[W2]   .place(WALL_H,          0,                 0);
  faces[W3]   .place(WALL_H + ROOM_W, WALL_H,           90);
  faces[W4]   .place(WALL_H,          WALL_H + ROOM_D, 180);

  for (Face f : faces) {
    f.pg = createGraphics(round(f.w * RENDER_SCALE), round(f.h * RENDER_SCALE), P3D);
  }
  matrixOut = createGraphics(round(MATRIX_W * RENDER_SCALE), round(MATRIX_H * RENDER_SCALE), P2D);
  testFont  = createFont("SansSerif", 96);

  println("Media matrix output: " + matrixOut.width + " x " + matrixOut.height + " px");
}

// ********************
//   Render
// ********************

void renderFaces() {
  for (Face f : faces) {
    PGraphics pg = f.pg;
    pg.beginDraw();
    pg.colorMode(HSB, 360, 100, 100, 100);
    pg.hint(DISABLE_DEPTH_TEST);
    pg.hint(ENABLE_STROKE_PURE);
    pg.background(0);

    // Flat world: 1 unit = 1 media matrix unit, shapes cross seams continuously
    flatCamera(pg, f);
    if (f.id == W1) pg.image(mosaicLayer, 0, 0, f.w, f.h);   // the trencadís mural (Mosaic.pde)
    if (SHOW_POEM) {
      for (PoemWord pw : poemWordsList) pw.display(pg, f);
    }
    for (TileFlight fl : flights) fl.displayFlat(pg, f);      // tiles travelling to WALL 1
    if (showTest) drawTestPattern(pg, f);

    // WALL 3: the new tile assembles here in 3D (path in Mosaic.pde starts on WALL 3)
    if (f.id == W3) {
      wallCamera(pg, f);
      for (TileFlight fl : flights) fl.displayMain(pg, f);
    }
    // Pieces flying through the room (3D travel), seen from the audience
    if (TRAVEL_3D) {
      viewerCamera(pg, f);
      for (TileFlight fl : flights) fl.display3D(pg);
    }
    // Main screen: text input
    if (f.id == MAIN_FACE && showUI) drawLLMInterface(pg);
    pg.endDraw();
  }
}

// Orthographic camera: 1 world unit = 1 media matrix unit, origin top-left
void flatCamera(PGraphics pg, Face f) {
  pg.ortho(-f.w/2, f.w/2, -f.h/2, f.h/2, 1, 4000);
  pg.camera(f.w/2, f.h/2, 1000, f.w/2, f.h/2, 0, 0, 1, 0);
}

// Perspective camera with the same mapping as flatCamera on the wall plane (z = 0),
// so a tile that tilts in 3D lines up exactly when it lies flat again.
void wallCamera(PGraphics pg, Face f) {
  float z0 = (f.h / 2) / tan(PI / 6);
  pg.perspective(PI / 3, f.w / f.h, z0 / 10, z0 * (ASSEMBLE_DEPTH + 3));   // far enough for the shards coming from the depth
  pg.camera(f.w/2, f.h/2, z0, f.w/2, f.h/2, 0, 0, 1, 0);
}

// 3D travel (TRAVEL_3D): every surface is seen from the audience's point of view
// (centre of the room, eye height), like a camera rig. Off-axis perspective: a point
// lying ON the surface lands on the same pixel as with flatCamera, so things in the
// air of the room line up across walls and floor, and the hand-over to the flat
// drawing (on WALL 3 and WALL 1) is seamless.
PVector viewerEye() {
  return new PVector(ROOM_W / 2, ROOM_D / 2, VIEWER_HEIGHT);
}

void viewerCamera(PGraphics pg, Face f) {
  PVector E = viewerEye();
  PVector r = PVector.sub(E, f.O);
  float eu = r.dot(f.eU), ev = r.dot(f.eV), d = r.dot(f.n);   // n points into the room → d > 0
  PVector C = PVector.sub(E, PVector.mult(f.n, d));            // foot of the eye on the surface
  pg.camera(E.x, E.y, E.z, C.x, C.y, C.z, f.eV.x, f.eV.y, f.eV.z);
  float near = d * 0.01, k = near / d;
  pg.frustum(-eu * k, (f.w - eu) * k, -(f.h - ev) * k, ev * k, near, d + ROOM_W + ROOM_D);
}

// Mouse drag for camera mode 5 (Ctrl+M): rotates the tile on the main wall
void updateCameraDrag() {
  if (camMode != 5 || !isDragging) return;
  camRotH += (mouseX - dragStartX) * 0.005;
  camRotV  = constrain(camRotV + (mouseY - dragStartY) * 0.003, -PI/2.5, PI/2.5);
  dragStartX = mouseX;
  dragStartY = mouseY;
}

// Packs the 5 surfaces into the media matrix layout
void composeMatrix() {
  matrixOut.beginDraw();
  matrixOut.background(0);
  matrixOut.imageMode(CENTER);
  for (Face f : faces) {
    matrixOut.pushMatrix();
    matrixOut.translate((f.mx + f.matrixW()/2) * RENDER_SCALE, (f.my + f.matrixH()/2) * RENDER_SCALE);
    matrixOut.rotate(radians(f.rot));
    matrixOut.image(f.pg, 0, 0);
    matrixOut.popMatrix();
  }
  matrixOut.endDraw();
}

// What you see in the Processing window (not part of the output)
void drawPreview() {
  background(0);
  int outIdx = viewMode - 1 - faces.length;                  // ≥ 0: an output image
  Face shown = (viewMode == 0 || outIdx >= 0) ? null : faces[viewMode - 1];
  PImage img = (outIdx >= 0) ? outImgs.get(outIdx) : (shown == null) ? matrixOut : shown.pg;
  float s = min(width / (float) img.width, height / (float) img.height);
  imageMode(CENTER);
  image(img, width/2, height/2, img.width * s, img.height * s);
  if (showOutlines && outIdx < 0) drawOutlines(img, s);

  fill(0, 0, 50);
  textSize(12);
  textAlign(LEFT, TOP);
  text(nf(frameRate, 0, 1) + " fps  ·  " + (outIdx >= 0 ? "OUTPUT " + (outIdx + 1) + ": " + outputName(outIdx) : shown == null ? "MEDIA MATRIX" : shown.name)
       + "  ·  Ctrl+V view  Ctrl+T test  Ctrl+L lines  Ctrl+E test mode  Ctrl+D 2D/3D  Ctrl+N reset WALL 1", 10, 10);
}

// Wall/floor outlines + names over the preview (never in the output)
void drawOutlines(PImage img, float s) {
  float ox = (width  - img.width  * s) / 2;
  float oy = (height - img.height * s) / 2;
  float k  = RENDER_SCALE * s;   // matrix units → window pixels
  noFill();
  stroke(0, 0, 45);
  strokeWeight(1);
  textSize(11);
  textAlign(LEFT, TOP);
  for (Face f : faces) {
    if (viewMode != 0 && f.id != viewMode - 1) continue;
    float x = (viewMode == 0) ? ox + f.mx * k : ox;
    float y = (viewMode == 0) ? oy + f.my * k : oy;
    float w = (viewMode == 0) ? f.matrixW() * k : img.width * s;
    float h = (viewMode == 0) ? f.matrixH() * k : img.height * s;
    rect(x, y, w, h);
    fill(0, 0, 45);
    text(f.name, x + 5, y + 4);
    noFill();
  }
}

// Calibration: grid, surface name and what is on the other side of each edge
void drawTestPattern(PGraphics pg, Face f) {
  pg.pushStyle();
  pg.blendMode(BLEND);
  pg.noFill();
  pg.stroke(0, 0, 35);
  pg.strokeWeight(max(1, 3 * RENDER_SCALE));
  for (float x = 0; x <= f.w; x += 250) pg.line(x, 0, x, f.h);
  for (float y = 0; y <= f.h; y += 250) pg.line(0, y, f.w, y);
  pg.stroke(0, 90, 100);
  pg.strokeWeight(max(2, 12 * RENDER_SCALE));
  pg.rect(0, 0, f.w, f.h);

  pg.fill(0, 0, 100);
  pg.textFont(testFont);
  pg.textAlign(CENTER, CENTER);
  pg.textSize(min(f.w, f.h) * 0.2);
  pg.text(f.name, f.w/2, f.h/2);

  float m = 90;
  pg.textSize(70);
  pg.fill(50, 80, 100);
  pg.text("↑ " + neighbourName(f, f.w/2, -1),   f.w/2, m);
  pg.text("↓ " + neighbourName(f, f.w/2, f.h+1), f.w/2, f.h - m);
  pg.pushMatrix();
  pg.translate(m, f.h/2);
  pg.rotate(-HALF_PI);
  pg.text("↑ " + neighbourName(f, -1, f.h/2), 0, 0);
  pg.popMatrix();
  pg.pushMatrix();
  pg.translate(f.w - m, f.h/2);
  pg.rotate(HALF_PI);
  pg.text("↑ " + neighbourName(f, f.w+1, f.h/2), 0, 0);
  pg.popMatrix();
  pg.popStyle();
}

String neighbourName(Face f, float u, float v) {
  int n = foldOver(f.id, f.toRoom(u, v));
  return (n < 0) ? "TECHO" : faces[n].name;
}

// ********************
//   Surface geometry
// ********************

// A point P that has left face 'fi' (still in its extended plane) is folded
// over the shared edge onto the neighbouring surface. Any direction vectors
// passed (velocity, up...) are folded the same way, in place.
// Returns the new face index, 'fi' if P is still inside, or -1 for the ceiling.
int foldOver(int fi, PVector P, PVector... dirs) {
  Face f = faces[fi];
  PVector r = PVector.sub(P, f.O);
  float u = r.dot(f.eU), v = r.dot(f.eV);
  PVector out;
  float d;
  if      (u < 0)   { out = PVector.mult(f.eU, -1); d = -u; }
  else if (u > f.w) { out = f.eU.copy();            d = u - f.w; }
  else if (v > f.h) { out = f.eV.copy();            d = v - f.h; }
  else if (v < 0)   {
    if (f.id != FLOOR) return -1;                   // top of a wall = ceiling
    out = PVector.mult(f.eV, -1); d = -v;
  }
  else return fi;

  // Leaving across an edge, the movement continues along this face's inward normal
  P.add(PVector.mult(out, -d)).add(PVector.mult(f.n, d));
  for (PVector w : dirs) {
    float s = w.dot(out);
    w.add(PVector.mult(out, -s)).add(PVector.mult(f.n, s));
  }

  // The new face is the one whose plane now contains P
  int best = fi;
  float bestDist = 1;
  for (Face g : faces) {
    if (g.id == fi) continue;
    float dist = abs(PVector.sub(P, g.O).dot(g.n));
    if (dist < bestDist) { bestDist = dist; best = g.id; }
  }
  return best;
}

int randomFaceByArea(Random rng) {
  float total = 0;
  for (Face f : faces) total += f.w * f.h;
  float r = rnd(rng, 0, total);
  for (Face f : faces) {
    r -= f.w * f.h;
    if (r <= 0) return f.id;
  }
  return FLOOR;
}

class Face {
  int id;
  String name;
  float w, h;               // upright size, media matrix units
  PVector O, eU, eV, n;     // 3D frame: origin, axes, inward normal
  float mx, my;             // top-left in the media matrix
  int rot;                  // rotation in the media matrix (degrees)
  PGraphics pg;

  Face(int id, String name, float w, float h, PVector O, PVector eU, PVector eV) {
    this.id = id; this.name = name;
    this.w = w; this.h = h;
    this.O = O; this.eU = eU; this.eV = eV;
    this.n = eU.cross(eV);
  }

  void place(float mx, float my, int rot) {
    this.mx = mx; this.my = my; this.rot = rot;
  }

  float matrixW() { return (rot % 180 == 0) ? w : h; }
  float matrixH() { return (rot % 180 == 0) ? h : w; }

  PVector toRoom(float u, float v) {
    return PVector.add(O, PVector.add(PVector.mult(eU, u), PVector.mult(eV, v)));
  }

  // Local (u, v) of a point lying on face 'src'. A neighbouring surface is unfolded
  // flat next to this one, so shapes continue across the seam. null = opposite wall.
  PVector localPoint(PVector P, Face src) {
    PVector Q = P.copy();
    if (src != this) {
      if (abs(src.n.dot(n)) > 0.5) return null;
      float d = PVector.sub(P, O).dot(n);
      Q.sub(PVector.mult(n, d)).sub(PVector.mult(src.n, d));
    }
    PVector r = PVector.sub(Q, O);
    return new PVector(r.dot(eU), r.dot(eV));
  }

  // Same unfolding for a direction vector tangent to 'src'
  PVector localDir(PVector D, Face src) {
    PVector Q = D.copy();
    if (src != this) {
      float d = D.dot(n);
      Q.sub(PVector.mult(n, d)).sub(PVector.mult(src.n, d));
    }
    return new PVector(Q.dot(eU), Q.dot(eV));
  }
}
