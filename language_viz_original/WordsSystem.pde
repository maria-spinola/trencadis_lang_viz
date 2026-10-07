// ═══════════════════════════════════════════════════════════
/* WordsSystem.pde
* CentralWord  -> fixed from input.json
* PoemWord     —> scattered around canvas from poem_words.json
*/
// ═══════════════════════════════════════════════════════════

JSONArray poemWords;
int poemWordCursor = 0;
int poemSpawnTimer = 0;

CentralWord centralWord = null;
ArrayList<PoemWord> poemWordsList = new ArrayList<>();

// ── Setup ──────────────────────────────────────────────────

void setupWords() {
  try {
    JSONObject poem = loadJSONObject("poem_words.json");
    poemWords = poem.getJSONArray("words");
    println("Loaded " + poemWords.size() + " poem words");
  } catch (Exception e) {
    println("Could not load poem_words.json: " + e.getMessage());
    poemWords = new JSONArray();
  }
}

JSONObject nextPoemWord() {
  if (poemWords == null || poemWords.size() == 0) return null;
  int wi = poemWordCursor % poemWords.size();
  poemWordCursor++;
  return poemWords.getJSONObject(wi);
}

// Called by JSONLoader
void spawnCentralWord() {
  centralWord = new CentralWord(
    pColorHex, pWordClass,
    pAbstract, pAgency, pOrganic, pPhenomenon, pTime
  );
}

// ********************
//   Update + Display
// ********************

void updateWords() {
  // Spawn poem words on timer
  poemSpawnTimer++;
  if (poemSpawnTimer >= POEM_SPAWN_INTERVAL) {
    poemSpawnTimer = 0;
    if (poemWordsList.size() < MAX_POEM_WORDS) {
      JSONObject wordObj = nextPoemWord();
      if (wordObj != null) poemWordsList.add(new PoemWord(wordObj));
    }
  }

  if (centralWord != null) centralWord.update();

  for (int i = poemWordsList.size()-1; i >= 0; i--) {
    poemWordsList.get(i).update();
    if (poemWordsList.get(i).isDead()) poemWordsList.remove(i);
  }
}

void displayWords() {
  if (showPoem) {
    for (PoemWord pw : poemWordsList) pw.display();
  }
  if (centralWord != null) centralWord.display();
}

// *****************
//   CENTRAL WORD
// *****************

class CentralWord {
  float life, lifeSpeed;
  boolean blooming;
  SymbolFormation sym;

  CentralWord(color col, int wordClass,
              int sAbstract, int sAgency, int sOrganic,
              int sPhenomenon, int sTime) {
    life      = 0;
    blooming  = true;
    lifeSpeed = map(sTime, 1, 7, 0.008, 0.001);

    // Centered at WEBGL origin (0,0)
    sym = new SymbolFormation(0, 0, col, wordClass,
                              sAbstract, sAgency, sOrganic, sPhenomenon,
                              200, 1.0, true);
  }

  void update() {
    if (blooming) {
      life += lifeSpeed;
      if (life >= 1.0) { life = 1.0; blooming = false; }
    }
    sym.update(life);
  }

  void display() {
    // Soft dark halo behind central word
    blendMode(BLEND);
    noStroke();
    fill(0, 0, 0, life * 70);
    float haloR = sym.scale * life;
    ellipse(0, 0, haloR * 2, haloR * 2);

    // Particles
    blendMode(ADD);
    sym.display(life * 85, life);
    blendMode(BLEND);
  }
}

// *****************
//    POEM WORDS
// *****************

class PoemWord {
  float wx, wy, wz;   // 3D position in WEBGL space
  float zSpeed;
  float alpha;

  SymbolFormation sym;

  PoemWord(JSONObject wordObj) {
    
    // Progressive angle to poem words appearance 
    float spawnAngle = poemWordCursor * 137.5 * (PI/180.0);
    float spawnDist  = random(480, width * 0.42);           
  
    wx = cos(spawnAngle) * spawnDist;
    wy = sin(spawnAngle) * spawnDist * 0.7;  // * 0.7 -> ellipse
    wz = -1200;
    zSpeed = random(0.8, 1.8);
    alpha  = 0;

    color wordColor  = parseHexColor(wordObj.getString("color_hex", "#FFFFFF"));
    int wordClass    = constrain(wordObj.getInt("word_class",      1), 1, 8);
    int phenomenon   = constrain(wordObj.getInt("phenomena_class", 1), 1, 7);
    int bAbstract    = constrain(wordObj.getInt("abstraction",     4), 1, 7);
    int bAgency      = constrain(wordObj.getInt("agency",          4), 1, 7);
    int bOrganic     = constrain(wordObj.getInt("organic",         4), 1, 7);

    // Blend poem color with a hint of hue cycle
    float glowHue    = (glowT * 0.5) % 360;
    float blendedHue = lerpAngle(hue(wordColor), glowHue, 0.2);
    color col        = color(blendedHue, saturation(wordColor), brightness(wordColor));

    sym = new SymbolFormation(wx, wy, col, wordClass, bAbstract, bAgency, bOrganic, phenomenon, 50, 0.6, false);
  }

  void update() {
    wz += zSpeed;

    // Alpha -> fade in if far, fade out when very close
    if (wz < -200) {
      alpha = map(wz, -1200, -200, 0, 255);
    } else {
      alpha = map(wz, -200, 350, 255, 0);
    }
    alpha = constrain(alpha, 0, 255);

    // Life follows z -> 0 = far, 1 = close
    float life = constrain(map(wz, -1200, 200, 0, 1), 0, 1);
    sym.update(life);
  }

  void display() {
    if (alpha < 1) return;
    float life = constrain(map(wz, -1200, 200, 0, 1), 0, 1);
    float perspScale = map(wz, -1200, 300, 0.15, 1.0);
    push();
    translate(wx * perspScale, wy * perspScale, wz);
    sym.display(alpha, life);
    pop();
  }

  boolean isDead() { 
    return wz > 350; 
  }
}
