// ═══════════════════════════════════════════════════════════
// JSONLoader.pde
// Watches input.json and updates Config parameters.
// ═══════════════════════════════════════════════════════════

import java.io.File;

String  jsonPath      = "input.json";
long    lastModified  = 0;
int     checkInterval = 30;
boolean autoReload    = true;

void checkFileChanged() {
  if (!autoReload) return;
  if (frameCount % checkInterval != 0) return;
  try {
    File f = new File(dataPath(jsonPath));
    if (!f.exists()) return;
    long modified = f.lastModified();
    if (modified != lastModified && lastModified != 0) {
      loadJSONFromPath(jsonPath);
    }
    lastModified = modified;
  } catch (Exception e) {}
}

void loadJSONFromPath(String path) {
  try {
    JSONObject j = loadJSONObject(path);
    if (j == null) return;

    pEmotion    = constrain(j.getInt("emotion",         pEmotion),    1, 7);
    pWordClass  = constrain(j.getInt("word_class",      pWordClass),  1, 8);
    pAbstract   = constrain(j.getInt("abstraction",     pAbstract),   1, 7);
    pAgency     = constrain(j.getInt("agency",          pAgency),     1, 7);
    pOrganic    = constrain(j.getInt("organic",         pOrganic),    1, 7);
    pPhenomenon = constrain(j.getInt("phenomena_class", pPhenomenon), 1, 7);
    pTime       = constrain(j.getInt("time_duration",   pTime),       1, 7);
    pColorHex   = parseHexColor(j.getString("color_hex", "#FFA500"));
    currentWord = j.hasKey("word") ? j.getString("word")
                : j.hasKey("emotion_label") ? j.getString("emotion_label")
                : "—";

    spawnCentralWord();
    if (midi != null) {
      playWord(pEmotion, pWordClass, pAbstract, pAgency, pOrganic, pPhenomenon, pTime);
    }


    File f = new File(dataPath(path));
    if (f.exists()) lastModified = f.lastModified();
    println("Loaded: " + currentWord);
  } catch (Exception e) {
    println("JSON error: " + e.getMessage());
  }
}
