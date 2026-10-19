// ════════════════════════════════════════════════════════════════
// CatalanLLM.pde
// Only ONE word in CATALAN is accepted. Two filters:
//   a) local, instant (here): one word, Catalan alphabet only
//   b) semantic, by the LLM in the same call as the parameters: es_catala / motiu
// A rejected word makes no tile, no input.json, no sound: a short message on the
// main wall instead. Every answer (also rejections) is cached in data/lexicon_cache.json,
// so a word is analysed only once and always gives the same tile.
// ════════════════════════════════════════════════════════════════

final String CAT_LETTERS = "abcdefghijklmnopqrstuvwxyzàèéíïòóúüç";

String pendingWord = "";      // the word waiting for the LLM (as typed, normalised)
int    msgUntil    = 0;       // frame until which displayText stays on the wall

// ── Normalising and the local filter ──────────────────────────────

// Trim, and "l.l" → "l·l" (the punt volat is hard to type)
String normalizeWord(String raw) {
  String w = raw.trim();
  w = w.replace("l.l", "l·l").replace("L.L", "L·L").replace("L.l", "L·l").replace("l.L", "l·L");
  w = w.replace("ŀl", "l·l").replace("Ŀl", "L·l");
  return w;
}

// The key for the cache: lower case
String cacheKey(String w) {
  return normalizeWord(w).toLowerCase();
}

// null if the word passes, otherwise the message to show
String checkLocalWord(String raw) {
  String w = normalizeWord(raw);
  if (w.length() == 0) return MSG_ONE_WORD;
  if (w.indexOf(' ') >= 0 || w.indexOf('\t') >= 0) return MSG_ONE_WORD;
  if (w.length() > MAX_WORD_LENGTH) return MSG_TOO_LONG;
  String lw = w.toLowerCase();
  for (int i = 0; i < lw.length(); i++) {
    char ch = lw.charAt(i);
    if (CAT_LETTERS.indexOf(ch) >= 0) continue;
    if (ch == '-') {                                // only inside compounds: pell-roja
      if (i == 0 || i == lw.length() - 1 || lw.charAt(i - 1) == '-') return MSG_ONE_WORD;
      continue;
    }
    if (ch == '·') {                                // only in l·l
      if (i == 0 || i == lw.length() - 1 || lw.charAt(i - 1) != 'l' || lw.charAt(i + 1) != 'l') return MSG_NOT_CATALAN;
      continue;
    }
    if (ch == '\'' || ch == '’') return MSG_ONE_WORD;   // l'aigua = two words
    return MSG_NOT_CATALAN;                        // numbers, symbols, emoji, ñ, á…
  }
  return null;
}

// Characters that can be typed into the box at all
boolean typable(char ch) {
  char lc = Character.toLowerCase(ch);
  return CAT_LETTERS.indexOf(lc) >= 0 || ch == '-' || ch == '·' || ch == '.';
}

// Dead keys done by hand: some keyboards / renderers don't compose accents.
// Type the accent first and then the vowel:  ` → à è ò   ´ or ' → é í ó ú   ¨ or " → ï ü
char pendingAccent = 0;

String composeAccent(char accent, char v) {
  String grave = "aàeèoòAÀEÈOÒ", acute = "eéiíoóuúEÉIÍOÓUÚ", diaer = "iïuüIÏUÜ";
  String table = (accent == '`') ? grave : (accent == '¨' || accent == '"') ? diaer : acute;
  for (int i = 0; i < table.length(); i += 2) if (table.charAt(i) == v) return "" + table.charAt(i + 1);
  return null;
}

// ── Submitting a word ─────────────────────────────────────────────

void showMessage(String m) {
  displayText = m;
  msgUntil = frameCount + MSG_FRAMES;
}

// Called by handleLLMKey() on Enter
void submitWord(String typed) {
  String word = normalizeWord(typed);
  String bad  = checkLocalWord(word);
  if (bad != null) {
    showMessage(bad);
    println("Rejected (local filter): \"" + typed + "\" — " + bad);
    return;
  }
  displayText = "";
  msgUntil = 0;
  String fixed = fixAccents(word);       // "cafe" → "cafè": a missing or wrong accent is corrected
  if (!fixed.equals(word)) {
    println("Accent fixed: \"" + word + "\" → \"" + fixed + "\"");
    word = fixed;
    showMessage(MSG_DID_YOU_MEAN.replace("%s", fixed));
  }
  lastPrompt = word;
  startReveal(word);                     // Reveal.pde: the word, big, on the main wall
  if (TEST_MODE && TEST_RANDOM) {        // random test: local filter only, random parameters
    llmModeUsed = "test";
    generateTestWord(word);
    return;
  }
  JSONObject cached = cacheGet(word);
  if (cached != null) {                  // already analysed: no LLM call, same tile as before
    llmModeUsed = "cache";
    println("From cache: " + word + "  [mode: cache — no LLM call]");
    applyLLMResult(word, cached, false);
    return;
  }
  if (LLM_PROVIDER.equals("claude")) {
    if (API_KEY.length() == 0) { generateRandomWord(word); return; }   // no key: parameters from the word itself
    pendingWord = word;
    llmModeUsed = "claude";
    callClaude(word);
  } else {
    pendingWord = word;
    callModel(word);
  }
  for (TileFlight fl : flights) if (fl.state == FLIGHT_HOLD) fl.depart();   // the last tile makes room for the thinking shards
}

// The model answered with a JSON object for pendingWord (from parseResponse, utils.pde)
void applyLLMResult(String word, JSONObject res, boolean store) {
  if (store && !res.hasKey("definicio") && pendingDef.length() > 0) res.setString("definicio", pendingDef);
  boolean ok = res.hasKey("es_catala") ? res.getBoolean("es_catala") : true;
  if (store) cachePut(word, res);
  if (!ok) {
    String why = res.hasKey("motiu") ? res.getString("motiu") : "";
    showMessage(MSG_NOT_CATALAN);
    endReveal();
    println("Rejected (LLM): \"" + word + "\"" + (why.length() > 0 ? " — " + why : "") + "  [mode: " + llmModeUsed + "]");
    return;
  }
  JSONObject out = cleanParams(res, word);
  println("Accepted: \"" + word + "\"  [mode: " + llmModeUsed + "]");
  saveJSONObject(out, "data/input.json");
  loadJSONFromPath(jsonPath);
}

// Validated copy with every value in range (the existing names and ranges are unchanged)
JSONObject cleanParams(JSONObject res, String word) {
  JSONObject out = new JSONObject();
  out.setString("word", word);
  out.setInt("emotion",         constrain(intOr(res, "emotion", 4), 1, 7));
  out.setString("emotion_label", res.hasKey("emotion_label") ? res.getString("emotion_label") : "");
  String hex = res.hasKey("color_hex") ? res.getString("color_hex").trim() : "";
  if (!hex.matches("^#[0-9A-Fa-f]{6}$")) hex = emotionHex(out.getInt("emotion"), 0, 70, 80);
  out.setString("color_hex", hex);
  out.setInt("word_class",      constrain(intOr(res, "word_class", 1), 1, 8));
  out.setInt("abstraction",     constrain(intOr(res, "abstraction", 4), 1, 7));
  out.setInt("agency",          constrain(intOr(res, "agency", 4), 1, 7));
  out.setInt("organic",         constrain(intOr(res, "organic", 4), 1, 7));
  out.setInt("phenomena_class", constrain(intOr(res, "phenomena_class", 1), 1, 7));
  out.setInt("time_duration",   constrain(intOr(res, "time_duration", 4), 1, 7));
  out.setInt("culturalitat",    constrain(intOr(res, "culturalitat", 1), 1, 7));
  out.setInt("raresa",          constrain(intOr(res, "raresa", 1), 1, 7));
  int zf = wordZipf(word);   // raresa measured from real Catalan texts (wordfreq), not guessed by the model
  String def = res.hasKey("definicio") ? res.getString("definicio") : "";
  if (zf >= 0 && def.startsWith("(forma de ")) {            // cantàvem is as common as cantar
    zf = max(zf, wordZipf(def.substring(10, max(10, def.indexOf(')')))));
  }
  if (zf >= 0) {
    out.setInt("raresa", raresaFromZipf(zf));
    out.setFloat("zipf", zf / 100.0);
  }
  if (res.hasKey("definicio")) out.setString("definicio", res.getString("definicio"));
  return out;
}

int intOr(JSONObject j, String k, int def) {
  if (!j.hasKey(k) || j.isNull(k)) return def;
  try { return j.getInt(k); } catch (Exception e) {
    try { return round(j.getFloat(k)); } catch (Exception e2) { return def; }
  }
}

// The model didn't answer: keep the installation going with parameters from the word itself
// (in that case the language is NOT checked by the LLM, only by the local filter)
void llmUnavailable(String why) {
  llmModeUsed = "fallback";
  println("LLM not available (" + why + "). [mode: fallback] Using parameters derived from the word, language not verified.");
  if (MSG_NO_LLM.length() > 0) showMessage(MSG_NO_LLM);
  if (pendingWord.length() > 0) generateRandomWord(pendingWord);
}

// ── The answer: JSON Schema that forces the exact fields and ranges ──

// The model writes the fields in this order (the schema forces it): first what the word is
// and its scales, the emotion and its colour last. With the emotion first, Salamandra copied
// the numbers of the prompt's example with the same emotion.
String[] ANSWER_FIELDS = { "es_catala", "motiu", "word_class", "phenomena_class", "abstraction", "agency", "organic",
                           "time_duration", "culturalitat", "raresa", "emotion", "emotion_label", "color_hex" };

String fieldSchema(String k) {
  if (k.equals("es_catala"))     return "{\"type\":\"boolean\"}";
  if (k.equals("motiu"))         return "{\"type\":\"string\",\"maxLength\":60}";   // short: it's only read in the console
  if (k.equals("emotion_label")) return "{\"type\":\"string\",\"enum\":[\"\",\"" + join(EMOTION_NAMES, "\",\"") + "\"]}";
  if (k.equals("color_hex"))     return "{\"type\":\"string\",\"pattern\":\"^#[0-9A-Fa-f]{6}$\"}";
  return "{\"type\":\"integer\",\"minimum\":1,\"maximum\":" + (k.equals("word_class") ? 8 : 7) + "}";
}

// Every field always (Ollama)
String analysisSchema() {
  String props = "", req = "";
  for (String k : ANSWER_FIELDS) {
    props += (props.length() > 0 ? "," : "") + "\"" + k + "\":" + fieldSchema(k);
    req   += (req.length() > 0 ? "," : "") + "\"" + k + "\"";
  }
  return "{\"type\":\"object\",\"properties\":{" + props + "},\"required\":[" + req + "]}";
}

// Two shapes (llama-server): a rejected word only says why, {"es_catala": false, "motiu": "…"};
// an accepted one has every parameter and no motiu. Shorter answers, and the rejection examples
// carry no numbers for the model to copy.
String twoShapeSchema() {
  String props = "\"es_catala\":{\"const\":true}", req = "\"es_catala\"";
  for (String k : ANSWER_FIELDS) {
    if (k.equals("es_catala") || k.equals("motiu")) continue;
    props += ",\"" + k + "\":" + fieldSchema(k);
    req   += ",\"" + k + "\"";
  }
  return "{\"anyOf\":["
    + "{\"type\":\"object\",\"properties\":{\"es_catala\":{\"const\":false},\"motiu\":" + fieldSchema("motiu") + "},\"required\":[\"es_catala\",\"motiu\"]},"
    + "{\"type\":\"object\",\"properties\":{" + props + "},\"required\":[" + req + "]}]}";
}

// ── Ollama request ────────────────────────────────────────────────

String buildOllamaJSON(String word, String model) {
  return "{"
    + "\"model\":\"" + model + "\","
    + "\"stream\":false,"
    + "\"options\":{\"temperature\":0},"
    + "\"format\":" + analysisSchema() + ","
    + "\"messages\":["
    +   "{\"role\":\"system\",\"content\":\"" + escapeJson(SYSTEM_PROMPT) + "\"},"
    +   "{\"role\":\"user\",\"content\":\"" + escapeJson(word) + "\"}"
    + "]}";
}

// ── Local / cloud ─────────────────────────────────────────────────

volatile String llmModeUsed = "";   // which mode answered the last word: local / cloud / fallback / cache / test

// The OLLAMA_API_KEY, or data/ollama_key.txt (ignored by git)
String ollamaKey() {
  if (OLLAMA_API_KEY.length() > 0) return OLLAMA_API_KEY;
  File f = new File(dataPath("ollama_key.txt"));
  if (!f.exists()) return "";
  String[] l = loadStrings(f.getAbsolutePath());
  if (l != null) for (String line : l) {               // the first line that isn't empty or a # comment
    String t = line.trim();
    if (t.length() == 0 || t.startsWith("#")) continue;
    if (t.contains("=")) t = t.substring(t.indexOf('=') + 1);   // also accepts OLLAMA_API_KEY = "…";
    return t.replaceAll("[\"';\\s]", "");
  }
  return "";
}

// One request; returns the raw answer, or throws if it can't be used (no connection, error…)
String ollamaRequest(String url, String model, String key, String word) throws Exception {
  HttpClient client = HttpClient.newBuilder().connectTimeout(java.time.Duration.ofSeconds(4)).build();
  HttpRequest.Builder b = HttpRequest.newBuilder()
    .uri(URI.create(url))
    .header("Content-Type", "application/json; charset=utf-8")
    .timeout(java.time.Duration.ofSeconds(120))
    .POST(HttpRequest.BodyPublishers.ofString(buildOllamaJSON(word, model), java.nio.charset.StandardCharsets.UTF_8));
  if (key.length() > 0) b.header("Authorization", "Bearer " + key);
  HttpResponse<String> res = client.send(b.build(), HttpResponse.BodyHandlers.ofString(java.nio.charset.StandardCharsets.UTF_8));
  JSONObject j = parseJSONObject(res.body());
  if (res.statusCode() != 200 || j == null || j.hasKey("error")) {
    String m = (j != null && j.hasKey("error")) ? j.getString("error") : "HTTP " + res.statusCode();
    if (m.contains("not found") && url.equals(OLLAMA_URL_LOCAL)) m += "  →  run: ollama pull " + model;
    throw new Exception(m);
  }
  return res.body();
}

// Local / cloud / auto, in order. Returns { raw answer, mode } or throws with every reason.
// The local model is Salamandra on llama-server (LOCAL_ENGINE "llamacpp", LocalLLM.pde) or Ollama.
String[] askModelChain(String word) throws Exception {
  String why = "";
  word = userMessage(word);   // the word + its definition from the Viquidiccionari
  boolean tryLocal = !LLM_MODE.equals("cloud"), tryCloud = !LLM_MODE.equals("local");
  if (tryLocal) {
    try {
      String raw = LOCAL_ENGINE.equals("llamacpp") ? llamaRequest(word) : ollamaRequest(OLLAMA_URL_LOCAL, OLLAMA_MODEL_LOCAL, "", word);
      return new String[] { raw, "local" };
    }
    catch (Exception e) { why += "local: " + msgOf(e); }
  }
  if (tryCloud) {
    String key = ollamaKey();
    if (key.length() == 0) why += (why.length() > 0 ? " · " : "") + "cloud: no key (data/ollama_key.txt)";
    else {
      try { return new String[] { ollamaRequest(OLLAMA_URL_CLOUD, OLLAMA_MODEL_CLOUD, key, word), "cloud" }; }
      catch (Exception e) { why += (why.length() > 0 ? " · " : "") + "cloud: " + msgOf(e); }
    }
  }
  throw new Exception(why);
}

String msgOf(Exception e) {
  return (e.getMessage() != null) ? e.getMessage() : e.getClass().getSimpleName();
}

// Synchronous call (used by the language test): { parsed result, mode }
Object[] askModelNow(String word) throws Exception {
  String[] r = askModelChain(word);
  return new Object[] { parseJSONObject(stripFences(answerText(r[0]))), r[1] };
}

String stripFences(String t) {
  return t.trim().replaceAll("(?s)^```(json)?\\s*", "").replaceAll("(?s)\\s*```$", "").trim();
}

// ── Cache ─────────────────────────────────────────────────────────

JSONObject lexicon;

void loadLexicon() {
  lexicon = new JSONObject();
  if (!USE_LEXICON_CACHE) return;
  File f = new File(dataPath(LEXICON_CACHE_FILE));
  if (!f.exists()) return;
  try {
    lexicon = loadJSONObject(f);
    println("Lexicon cache: " + lexicon.size() + " words");
  } catch (Exception e) {
    println("Could not read " + LEXICON_CACHE_FILE + ": " + e.getMessage());
    lexicon = new JSONObject();
  }
}

JSONObject cacheGet(String word) {
  if (!USE_LEXICON_CACHE || lexicon == null) return null;
  String k = cacheKey(word);
  return lexicon.hasKey(k) ? lexicon.getJSONObject(k) : null;
}

void cachePut(String word, JSONObject res) {
  if (!USE_LEXICON_CACHE || lexicon == null) return;
  lexicon.setJSONObject(cacheKey(word), res);
  saveJSONObject(lexicon, dataPath(LEXICON_CACHE_FILE));
}

// ── Language test (Ctrl+K): both filters and the model on a list of words ──

String[] TEST_ACCEPT = { "casa", "taula", "gos", "paraula", "hola", "sardana", "castellers", "escudella",
  "calçot", "seny", "rauxa", "enyorança", "xiuxiuejar", "fesol", "espardenya", "trencadís", "estimar",
  "córrer", "tristesa", "infinit", "mar", "Montserrat", "col·lecció", "cantàvem" };
String[] TEST_REJECT = { "perro", "hello", "gatto", "mañana", "bueno", "dues paraules", "l'aigua",
  "casa123", "gaaat", ":)", "" };

void runLanguageTest() {
  new Thread(() -> {
    StringBuilder out = new StringBuilder();
    out.append("LLM_MODE " + LLM_MODE + " · local " + localModelName() + " · cloud " + OLLAMA_MODEL_CLOUD + (ollamaKey().length() > 0 ? "" : " (no key)") + "\n");
    out.append(String.format("%-14s %-9s %-8s %-6s %-42s %s%n", "word", "expected", "result", "mode", "reason", "emo cls abs agn org phe tim cul rar color"));
    int good = 0, total = 0;
    boolean llmOk = true;
    for (int pass = 0; pass < 2; pass++) {
      String[] list = (pass == 0) ? TEST_ACCEPT : TEST_REJECT;
      for (String w : list) {
        total++;
        String expected = (pass == 0) ? "accept" : "reject";
        String result, reason = "", params = "", mode = "";
        String bad = checkLocalWord(w);
        if (bad != null) { result = "reject"; reason = "local: " + bad; }
        else if (!llmOk) { result = "?"; reason = "LLM not available"; }
        else {
          try {
            Object[] ans = askModelNow(normalizeWord(w));
            JSONObject r = (JSONObject) ans[0];
            mode = (String) ans[1];
            boolean ok = r.hasKey("es_catala") && r.getBoolean("es_catala");
            result = ok ? "accept" : "reject";
            reason = "LLM: " + (r.hasKey("motiu") ? r.getString("motiu") : "");
            if (ok) {
              JSONObject c = cleanParams(r, w);
              params = String.format("%3d %3d %3d %3d %3d %3d %3d %3d %3d %s", c.getInt("emotion"), c.getInt("word_class"),
                c.getInt("abstraction"), c.getInt("agency"), c.getInt("organic"), c.getInt("phenomena_class"),
                c.getInt("time_duration"), c.getInt("culturalitat"), c.getInt("raresa"), c.getString("color_hex"));
            }
          } catch (Exception e) {
            llmOk = false;
            result = "?";
            reason = "LLM not available: " + msgOf(e);
          }
        }
        if (result.equals(expected)) good++;
        if (reason.length() > 42) reason = reason.substring(0, 41) + "…";
        out.append(String.format("%-14s %-9s %-8s %-6s %-42s %s%n", "\"" + w + "\"", expected, result + (result.equals(expected) ? "" : " ✗"), mode, reason, params));
      }
    }
    out.append(good + " / " + total + " as expected\n");
    println(out);
    saveStrings(dataPath("language_test.txt"), out.toString().split("\n"));
    println("Saved to data/language_test.txt");
  }).start();
}

// ── Prefill words (Ctrl+A): the list for MURAL_PREFILL analysed exactly as if typed ──
// data/prefill_list.txt (one word per line, # = comment) → Viquidiccionari + the model (or the
// cache) + measured raresa → data/prefill_words.json. Every answer also goes into the cache, so a
// visitor typing one of these words gets the same tile. Words the model rejects are left out.
volatile boolean prefillBusy = false;

void analysePrefillWords() {
  if (prefillBusy) { println("Prefill analysis already running"); return; }
  String[] lines = loadStrings(PREFILL_LIST_FILE);
  if (lines == null) { println("Prefill: " + PREFILL_LIST_FILE + " missing"); return; }
  prefillBusy = true;
  new Thread(() -> {
    JSONArray out = new JSONArray();
    StringList rejected = new StringList(), failed = new StringList();
    int n = 0, fromModel = 0;
    for (String l : lines) {
      String w = normalizeWord(l.trim());
      if (w.length() == 0 || w.startsWith("#")) continue;
      n++;
      if (checkLocalWord(w) != null) { rejected.append(w + " (local filter)"); continue; }
      JSONObject res = cacheGet(w);
      String mode = "cache";
      if (res == null) {
        try {
          Thread.sleep(PREFILL_PAUSE_MS);   // gently: the Viquidiccionari refuses too many requests in a row (HTTP 429)
          Object[] ans = askModelNow(w);
          res = (JSONObject) ans[0];
          mode = (String) ans[1];
          if (res == null) throw new Exception("unreadable answer");
          if (!res.hasKey("definicio") && pendingDef.length() > 0) res.setString("definicio", pendingDef);
          cachePut(w, res);
          fromModel++;
        } catch (Exception e) { failed.append(w + " (" + msgOf(e) + ")"); println("Prefill: " + w + " failed: " + msgOf(e)); continue; }
      }
      boolean ok = !res.hasKey("es_catala") || res.getBoolean("es_catala");
      if (!ok) { rejected.append(w + " (" + (res.hasKey("motiu") ? res.getString("motiu") : "model") + ")"); continue; }
      JSONObject c = cleanParams(res, w);
      c.remove("definicio");
      out.append(c);
      println("Prefill " + n + ": " + w + "  [" + mode + "]  emo " + c.getInt("emotion") + " cls " + c.getInt("word_class") + " cul " + c.getInt("culturalitat") + " rar " + c.getInt("raresa") + " " + c.getString("color_hex"));
    }
    JSONObject o = new JSONObject();
    o.setString("about", "Words to start the mural partly full (MURAL_PREFILL in Config.pde), analysed by the model as if typed (Ctrl+A, from " + PREFILL_LIST_FILE + ")");
    o.setJSONArray("words", out);
    saveJSONObject(o, dataPath(PREFILL_FILE));
    println("Prefill analysis: " + out.size() + " of " + n + " words saved to data/" + PREFILL_FILE + " (" + fromModel + " asked to the model, the rest from the cache)");
    if (rejected.size() > 0) println("  rejected: " + join(rejected.array(), ", "));
    if (failed.size() > 0)   println("  failed (run Ctrl+A again to retry): " + join(failed.array(), ", "));
    prefillBusy = false;
  }).start();
}

// ********************
//   Analysis printout
// ********************

String[] WORD_CLASS_NAMES = { "nom", "verb", "adjectiu", "adverbi", "preposició", "determinant", "pronom", "conjunció" };
String[] PHENOMENON_NAMES = { "objecte", "estat", "ésser", "matèria", "percepció", "acció", "lloc" };
String[] EMOTION_NAMES    = { "Ira", "Sorpresa", "Por", "Amor", "Fàstic", "Tristesa", "Alegria" };
String[] lastAnalysis = new String[0];   // shown on the preview window in test mode

String pad(String v) { while (v.length() < 16) v += " "; return v; }

// One line per category, with what each one changes in the tile (called by loadJSONFromPath)
void printAnalysis(JSONObject j) {
  int em = constrain(j.getInt("emotion", 4), 1, 7);
  int wc = constrain(j.getInt("word_class", 1), 1, 8);
  int ph = constrain(j.getInt("phenomena_class", 1), 1, 7);
  lastAnalysis = new String[] {
    "\"" + j.getString("word", "") + "\"   mode " + llmModeUsed,
    "emoció         " + pad(em + "  " + EMOTION_NAMES[em - 1]) + "→ color, so",
    "color          " + j.getString("color_hex", ""),
    "classe         " + pad(wc + "  " + WORD_CLASS_NAMES[wc - 1]) + "→ entrada al mur",
    "fenomen        " + pad(ph + "  " + PHENOMENON_NAMES[ph - 1]) + "→ dibuix del rajol",
    "abstracció     " + pad("" + j.getInt("abstraction", 4)) + "→ mida dels bocins",
    "agència        " + j.getInt("agency", 4),
    "orgànic        " + pad("" + j.getInt("organic", 4)) + "→ irregularitat dels talls",
    "temps          " + j.getInt("time_duration", 4),
    "culturalitat   " + pad("" + j.getInt("culturalitat", 1)) + "→ quants bocins, d'altres rajols",
    "raresa         " + pad(j.getInt("raresa", 1) + (j.hasKey("zipf") ? "  freq " + nf(j.getFloat("zipf"), 1, 2) : "")) + "→ mida del rajol, daurats",
    "significat     " + shorten(j.getString("definicio", "—"), 48) };
  println("── Anàlisi ──────────────────────────");
  for (String s : lastAnalysis) println("  " + s);
  println("─────────────────────────────────────");
}

String shorten(String s, int n) { return s.length() <= n ? s : s.substring(0, n - 1) + "…"; }

// ********************
//   Viquidiccionari
// ********************
// Small models don't know many Catalan words (gemma: "pessigolles" = a town), so the
// model gets the word's definition from the Catalan Wiktionary to understand it.

volatile String pendingDef = "";   // definition of the word being analysed ("" = none)

// The text sent to the model: the word, plus what the dictionary says about it
String userMessage(String word) {
  pendingDef = "";
  if (!USE_DICTIONARY) return word;
  String d = null;
  boolean reached = true;
  try {
    d = lookupDefinition(word);
    if (d == null && !word.equals(word.toLowerCase())) d = lookupDefinition(word.toLowerCase());
    if (d == null) d = lookupDefinition(word.substring(0, 1).toUpperCase() + word.substring(1));   // place names
  } catch (Exception e) {
    reached = false;
    println("Viquidiccionari not reachable (" + msgOf(e) + "): the model decides alone");
  }
  if (!reached)   return word;
  if (d == null)  { println("Viquidiccionari: \"" + word + "\" not found"); return word + "\n(Aquesta paraula no és al Viquidiccionari.)"; }
  if (d.isEmpty()) { println("Viquidiccionari: \"" + word + "\" is not a Catalan entry"); return word + "\n(El Viquidiccionari té aquesta pàgina, però no com a paraula catalana.)"; }
  pendingDef = d;
  println("Viquidiccionari: " + word + " = " + d);
  return word + "\nDefinició del Viquidiccionari: " + d;
}

// null = no page · "" = page without a Catalan entry · otherwise up to 3 definitions
String lookupDefinition(String word) throws Exception { return lookupDefinition(word, true); }

String lookupDefinition(String word, boolean followForms) throws Exception {
  String url = DICT_URL + "?action=parse&prop=wikitext&format=json&formatversion=2&redirects=1&page="
             + java.net.URLEncoder.encode(word, "UTF-8").replace("+", "%20");
  HttpClient client = HttpClient.newBuilder().connectTimeout(java.time.Duration.ofSeconds(4)).build();
  HttpRequest req = HttpRequest.newBuilder().uri(URI.create(url))
    .header("User-Agent", "trencadis-language-visualizer (Processing)")
    .timeout(java.time.Duration.ofSeconds(6)).GET().build();
  HttpResponse<String> res = client.send(req, HttpResponse.BodyHandlers.ofString(java.nio.charset.StandardCharsets.UTF_8));
  JSONObject j = parseJSONObject(res.body());
  if (j == null) throw new Exception("HTTP " + res.statusCode());
  if (j.hasKey("error")) return null;
  String t = j.getJSONObject("parse").getString("wikitext");
  java.util.regex.Matcher m = java.util.regex.Pattern.compile("\\{\\{-ca-\\}\\}(.*?)(\n== \\{\\{-|\\z)", java.util.regex.Pattern.DOTALL).matcher(t);
  if (!m.find()) return "";
  StringList defs = new StringList();
  String lemma = null;   // inflected forms (castellers, cantàvem, bonica) point to their base word
  java.util.regex.Matcher fm = java.util.regex.Pattern.compile("\\{\\{(?:forma-[a-z]+\\|ca|ca-forma-conj)\\|([^|}]+)").matcher(m.group(1));
  if (fm.find()) lemma = fm.group(1).trim();
  for (String l : m.group(1).split("\n")) {
    if (!l.startsWith("#") || l.startsWith("#:") || l.startsWith("#*")) continue;
    String d = l.replaceAll("^#+", "").trim()
                .replaceAll("\\{\\{[^}]*\\}\\}", "")                        // templates (region marks…)
                .replaceAll("\\[\\[(?:[^|\\]]*\\|)?([^\\]]*)\\]\\]", "$1")       // [[link|text]] → text
                .replaceAll("''+", "").replaceAll("\\s+", " ").trim();
    if (d.length() > 0 && defs.size() < 3) defs.append(d);
  }
  if (defs.size() == 0 && lemma != null && followForms) {
    String d = lookupDefinition(lemma, false);
    if (d != null && d.length() > 0) return "(forma de " + lemma + ") " + d;
  }
  return defs.size() == 0 ? "" : join(defs.array(), " / ");
}

// ********************
//   Word frequency (raresa)
// ********************
// data/catalan_freq.tsv: 185 000 Catalan words with their zipf frequency × 100, from
// wordfreq (CC BY-SA 4.0; made with tools/make_catalan_freq.py). zipf 6 = in every
// sentence, 3 = once per million words, 0 = never seen.

HashMap<String, Integer> wordFreq;

void loadWordFreq() {
  wordFreq = new HashMap<String, Integer>();
  if (!USE_WORD_FREQ) return;
  String[] lines = loadStrings(WORD_FREQ_FILE);
  if (lines == null) { println("Word frequencies: " + WORD_FREQ_FILE + " missing — raresa comes from the model"); return; }
  for (String l : lines) {
    int t = l.indexOf('\t');
    if (t > 0) wordFreq.put(l.substring(0, t), int(l.substring(t + 1)));
  }
  println("Word frequencies: " + wordFreq.size() + " Catalan words");
  buildAccentIndex();
}

// ── Missing or wrong accents ──
// Every word of the table is indexed without its accents (and ç → c): "cafe" → cafè, "musica" →
// música, "avio" → avió, "esperanca" → esperança. A typed word is only corrected when the form
// with the accent is much more common (ACCENT_FIX_GAP): "mes", "te", "mon", "ma", "sol" are words
// too, as common as "més", "té", "món", "mà", "sòl", and stay as typed.

HashMap<String, String> accentBest;    // word without accents → its most common written form
HashMap<String, Integer> accentBestZ;

String stripAccents(String w) {
  String acc = "àèéíïòóúüç", plain = "aeeiioouuc";
  StringBuilder b = new StringBuilder();
  for (char c : w.toCharArray()) { int i = acc.indexOf(c); b.append(i >= 0 ? plain.charAt(i) : c); }
  return b.toString();
}

void buildAccentIndex() {
  accentBest = new HashMap<String, String>();
  accentBestZ = new HashMap<String, Integer>();
  for (java.util.Map.Entry<String, Integer> e : wordFreq.entrySet()) {
    String w = e.getKey();
    boolean ok = w.length() > 0;
    for (char c : w.toCharArray()) if (CAT_LETTERS.indexOf(c) < 0 && c != '·' && c != '-') { ok = false; break; }
    if (!ok) continue;
    String k = stripAccents(w);
    Integer z = accentBestZ.get(k);
    if (z == null || e.getValue() > z) { accentBest.put(k, w); accentBestZ.put(k, e.getValue()); }
  }
}

// The word with its accents put right, or the word itself
String fixAccents(String word) {
  if (!USE_ACCENT_FIX || accentBest == null || accentBest.isEmpty()) return word;
  String low = word.toLowerCase();
  String best = accentBest.get(stripAccents(low));
  if (best == null || best.equals(low)) return word;
  int zTyped = wordZipf(low), zBest = accentBestZ.get(stripAccents(low));
  // A word typed WITH an accent: if it's common, it's a word in its own right — the diacritic accents
  // pèl / pel, fóra / fora, vós / vos, sòl / sol — and stays; if it's rare ("mès", "pà", "àrbre"),
  // it's most likely a wrong accent and a smaller gap is enough
  boolean accented = !stripAccents(low).equals(low);
  if (accented && zTyped >= ACCENT_WRONG_MAX * 100) return word;
  float gap = accented ? ACCENT_FIX_GAP_WRONG : ACCENT_FIX_GAP;
  if (zBest < ACCENT_FIX_MIN * 100 || zBest - zTyped < gap * 100) return word;
  // keep a capital first letter (place names)
  return Character.isUpperCase(word.charAt(0)) ? Character.toUpperCase(best.charAt(0)) + best.substring(1) : best;
}

// zipf × 100 of the word; 0 if it never appears; −1 if there is no table (the model's raresa stays)
int wordZipf(String word) {
  if (!USE_WORD_FREQ || wordFreq == null || wordFreq.isEmpty()) return -1;
  Integer z = wordFreq.get(word.toLowerCase());
  return z == null ? 0 : z;
}

// zipf → raresa 1..7 (RARESA_ZIPF: lower limit of raresa 1, 2, 3… 6)
int raresaFromZipf(int z) {
  for (int i = 0; i < RARESA_ZIPF.length; i++) if (z >= RARESA_ZIPF[i] * 100) return i + 1;
  return 7;
}

