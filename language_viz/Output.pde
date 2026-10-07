// ═══════════════════════════════════════════════════════════
// Output.pde
// How the room leaves Processing.
//
// The media matrix (matrixOut, Room.pde) is always made. Besides,
// OUTPUT_GROUPS (Config.pde) makes one image per group of surfaces,
// side by side, upright, left → right in the order written:
//
//   {}                                    → only the media matrix
//   { {W1, W2, W3, W4, FLOOR} }           → one image, all in a row
//   { {W1, W2}, {W3, W4}, {FLOOR} }       → three images (2 + 2 + 1)
//   { {W1, W2}, {W3, W4, FLOOR} }         → two images (2 + 3)
//   { {W1}, {W2}, {W3}, {W4}, {FLOOR} }   → one image per surface
//
// Each image can go out:
//   · in its own window (OUTPUT_WINDOWS), full screen on a given display —
//     no library needed, but every frame is copied through the CPU (slower)
//   · to PIXERA by Syphon (macOS) or Spout (Windows), one input per image —
//     the efficient way when PIXERA runs on the same computer. Install the
//     library and uncomment the lines marked SYPHON or SPOUT below and in
//     language_viz.pde.
// Ctrl+V also cycles through the output images in the preview.
// ═══════════════════════════════════════════════════════════

ArrayList<PGraphics> outImgs = new ArrayList<PGraphics>();
ArrayList<OutputWindow> outWins = new ArrayList<OutputWindow>();

// SYPHON (macOS):  ArrayList<SyphonServer> syphons = new ArrayList<SyphonServer>();
// SPOUT (Windows): ArrayList<Spout> spouts = new ArrayList<Spout>();

void setupOutputs() {
  for (int g = 0; g < OUTPUT_GROUPS.length; g++) {
    int w = 0, h = 0;
    for (int id : OUTPUT_GROUPS[g]) {
      w += faces[id].pg.width;
      h  = max(h, faces[id].pg.height);
    }
    outImgs.add(createGraphics(w, h, P2D));
    println("Output " + (g + 1) + ": " + outputName(g) + "  —  " + w + " x " + h + " px");

    if (OUTPUT_WINDOWS) outWins.add(new OutputWindow(g, w, h));   // opened after the first frame (openOutputWindows)
    // SYPHON: syphons.add(new SyphonServer(this, "language_viz " + (g + 1)));
    // SPOUT:  Spout sp = new Spout(this); sp.setSenderName("language_viz " + (g + 1)); spouts.add(sp);
  }
  // Only the media matrix:
  // SYPHON: if (OUTPUT_GROUPS.length == 0) syphons.add(new SyphonServer(this, "language_viz"));
  // SPOUT:  if (OUTPUT_GROUPS.length == 0) { Spout sp = new Spout(this); sp.setSenderName("language_viz"); spouts.add(sp); }
}

String outputName(int g) {
  String s = "";
  for (int id : OUTPUT_GROUPS[g]) s += (s.length() > 0 ? " + " : "") + faces[id].name;
  return s;
}

// Opening other windows from setup() hangs Java on macOS (OpenGL), so they open once the sketch runs
void openOutputWindows() {
  for (int g = 0; g < outWins.size(); g++) PApplet.runSketch(new String[] { "Output" + (g + 1) }, outWins.get(g));
}

// After composeMatrix(): fills each output image and sends it
void composeOutputs() {
  if (frameCount == 2) openOutputWindows();
  for (int g = 0; g < outImgs.size(); g++) {
    PGraphics o = outImgs.get(g);
    o.beginDraw();
    o.background(0);
    int x = 0;
    for (int id : OUTPUT_GROUPS[g]) {
      o.image(faces[id].pg, x, 0);
      x += faces[id].pg.width;
    }
    o.endDraw();
    if (OUTPUT_WINDOWS && frameCount > 2) outWins.get(g).push(o);
    // SYPHON: syphons.get(g).sendImage(o);
    // SPOUT:  spouts.get(g).sendTexture(o);
  }
  // Only the media matrix:
  // SYPHON: if (OUTPUT_GROUPS.length == 0) syphons.get(0).sendImage(matrixOut);
  // SPOUT:  if (OUTPUT_GROUPS.length == 0) spouts.get(0).sendTexture(matrixOut);
}

// One output image in its own window. Full screen on OUTPUT_DISPLAYS[index]
// (1 = main screen, 2 = second...), or a small window if 0 / not given.
public class OutputWindow extends PApplet {
  int index, srcW, srcH;
  PImage buf;
  final Object lock = new Object();
  boolean fresh = false;

  OutputWindow(int index, int w, int h) {
    this.index = index;
    srcW = w;
    srcH = h;
    buf = new PImage(w, h, RGB);
  }

  public void settings() {
    pixelDensity(1);
    int d = (index < OUTPUT_DISPLAYS.length) ? OUTPUT_DISPLAYS[index] : 0;
    if (d > 0) fullScreen(d);
    else       size(min(960, srcW), max(60, round(min(960, srcW) * srcH / (float) srcW)));
  }

  public void setup() {
    surface.setTitle("Output " + (index + 1) + " · " + outputName(index));
    noCursor();
  }

  public void draw() {
    background(0);
    synchronized (lock) {
      if (fresh) { buf.updatePixels(); fresh = false; }
      float s = min(width / (float) srcW, height / (float) srcH);
      image(buf, (width - srcW * s) / 2, (height - srcH * s) / 2, srcW * s, srcH * s);
    }
  }

  // Called from the main sketch after composing (copies the pixels)
  void push(PGraphics o) {
    o.loadPixels();
    synchronized (lock) {
      arrayCopy(o.pixels, buf.pixels);
      fresh = true;
    }
  }
}
