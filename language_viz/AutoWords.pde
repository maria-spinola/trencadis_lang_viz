// ═══════════════════════════════════════════════════════════
// AutoWords.pde
// When nobody has typed for a while, the room writes a word by itself: a word of the poem,
// typed letter by letter in the text box (with the keyboard sound), then ENTER — and it takes
// the same path as a visitor's word (its tile forms, breaks, travels and settles; it goes down
// to the floor). So the room is never still. Any key a visitor presses takes over at once.
// Settings: AUTO_WORDS, AUTO_IDLE_SECONDS, AUTO_TYPE_MS, AUTO_WORDS_LIST in Config.pde.
// ═══════════════════════════════════════════════════════════

int lastInteraction = 0;   // millis() of the last key a visitor pressed
int lastBusy = 0;          // millis() of the last moment something was happening (a word on its way)
String autoWord = null;    // the word being typed by the room (null = none)
int autoTyped = 0, autoNextKey = 0, autoWordNext = 0;

// A visitor pressed a key (language_viz.pde): the room stops typing and gives the box back
void noteInteraction() {
  lastInteraction = millis();
  if (autoWord != null) { autoWord = null; inputText = ""; }
}

boolean roomBusy() {
  if (isLoading || revealAlpha() > 0.01) return true;
  for (TileFlight fl : flights) if (!fl.landed) return true;
  return false;
}

void updateAutoWords() {
  if (!AUTO_WORDS || AUTO_WORDS_LIST.length == 0) return;
  int now = millis();
  if (autoWord != null) {   // typing, one letter at a time, at a human pace
    if (now < autoNextKey) return;
    if (autoTyped < autoWord.length()) {
      autoTyped++;
      inputText = autoWord.substring(0, autoTyped);
      autoKeySound();
      autoNextKey = now + round(AUTO_TYPE_MS * random(0.6, 1.5)) + (autoTyped == autoWord.length() ? AUTO_TYPE_MS * 3 : 0);   // a pause before ENTER
    } else {
      String w = autoWord;
      autoWord = null;
      inputText = "";
      autoKeySound();
      println("Auto word (no interaction for " + AUTO_IDLE_SECONDS + " s): " + w);
      submitWord(w);   // CatalanLLM.pde: the same path as a visitor's word
      lastBusy = now;
    }
    return;
  }
  if (roomBusy() || inputText.length() > 0) { lastBusy = now; return; }
  if (now - max(lastInteraction, lastBusy) < AUTO_IDLE_SECONDS * 1000) return;
  autoWord = nextAutoWord();
  autoTyped = 0;
  autoNextKey = now;
}

// The next word of the list, in order; one already in this round of the mural is skipped
// (unless they all are), so the mural doesn't fill with the same tiles
String nextAutoWord() {
  int n = AUTO_WORDS_LIST.length;
  for (int k = 0; k < n; k++) {
    String w = AUTO_WORDS_LIST[(autoWordNext + k) % n].trim();
    boolean there = false;
    for (int i = 0; i < mosaicTiles.size() && !there; i++) {
      JSONObject r = mosaicTiles.getJSONObject(i);
      there = r.getInt("cycle", 0) == mosaicCycle && r.getString("word", "").equalsIgnoreCase(w);
    }
    if (!there) { autoWordNext = (autoWordNext + k + 1) % n; return w; }
  }
  String w = AUTO_WORDS_LIST[autoWordNext % n].trim();
  autoWordNext = (autoWordNext + 1) % n;
  return w;
}

void autoKeySound() {
  try { if (soundReady) playNote(7, 48, floor(random(45, 60)), 250); } catch (Exception e) { }   // the same as a visitor's keys
}
