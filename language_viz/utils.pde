// ════════════════════════════════════════════════════════════════
//  Utils.pde
//  Utility functions: file I/O, HTTP body builder, JSON helpers
// ════════════════════════════════════════════════════════════════

import java.nio.file.Files;
import java.nio.file.Paths;


// ════════════════════════════════════════════════════════════════
//  LOAD SYSTEM PROMPT FROM .md FILE
// ════════════════════════════════════════════════════════════════

String loadSystemPrompt(String relativePath) {
  try {
    String fullPath = sketchPath(relativePath);
    byte[] bytes = Files.readAllBytes(Paths.get(fullPath));
    println("SUCCESS loading system prompt: " + fullPath);
    return new String(bytes, "UTF-8").trim();
  } catch (Exception e) {
    println("ERROR loading system prompt: " + e.getMessage());
    return "";
  }
}


// ════════════════════════════════════════════════════════════════
//  SAVE RESPONSE TO data/input.json
//
//  Strips the markdown code fence (```json ... ```) that the system
//  prompt causes Claude to wrap around its JSON output, then saves
//  the inner object directly — no outer wrapper field.
// ════════════════════════════════════════════════════════════════



// ════════════════════════════════════════════════════════════════
//  BUILD API REQUEST BODY
//  temperature is a model parameter in the body — NOT an HTTP header.
// ════════════════════════════════════════════════════════════════

String buildRequestJSON(String userInput) {
  return "{"
    + "\"model\":\""       + MODEL                     + "\","
    + "\"max_tokens\":1024,"
    + "\"temperature\":0,"
    + "\"system\":\""      + escapeJson(SYSTEM_PROMPT) + "\","
    + "\"messages\":[{"
    +   "\"role\":\"user\","
    +   "\"content\":\"" + escapeJson(userInput)       + "\""
    + "}]"
    + "}";
}


// ════════════════════════════════════════════════════════════════
//  JSON STRING ESCAPER
// ════════════════════════════════════════════════════════════════

String escapeJson(String s) {
  if (s == null) return "";
  return s
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
    .replace("\n",  "\\n")
    .replace("\r",  "\\r")
    .replace("\t",  "\\t");
}


// ════════════════════════════════════════════════════════════════
//  PARSE API RESPONSE  —  called from draw() on the main thread
// ════════════════════════════════════════════════════════════════

void parseResponse() {
  String raw = responseRaw;   // local copy
  responseRaw = null;         // clear volatile flag first
  isLoading   = false;

  try {
    JSONObject json = parseJSONObject(raw);

    // ── Packed connection error from the background thread
    if (json.hasKey("connection_error")) {
      llmUnavailable(json.getString("connection_error"));
      return;
    }

    // ── Error from Ollama {"error":"model 'x' not found…"} or Anthropic {"error":{"message":…}}
    if (json.hasKey("error")) {
      String m;
      try { m = json.getJSONObject("error").getString("message"); } catch (Exception e) { m = json.getString("error"); }
      llmUnavailable(m);
      return;
    }

    // ── Success
    String responseText = answerText(raw);
    JSONObject result = parseJSONObject(stripFences(responseText));
    if (result == null) { llmUnavailable("unreadable answer: " + responseText); return; }
    if (msgUntil == 0) displayText = "";   // clear any previous error message (not a "Volies dir…?" still showing)
    applyLLMResult(pendingWord, result, true);   // CatalanLLM.pde: reject, or validate + save input.json

  } catch (Exception e) {
    llmUnavailable("parse error: " + e.getMessage());
  }
}

// The model's text in a raw answer: Ollama {"message":{"content":"…"}}, Anthropic
// {"content":[{"text":"…"}]}, or llama-server's answer itself (LocalLLM.pde)
String answerText(String raw) {
  JSONObject j = parseJSONObject(raw);
  if (j == null) return raw;
  if (j.hasKey("message")) return j.getJSONObject("message").getString("content");
  if (j.hasKey("content") && j.get("content") instanceof JSONArray) return j.getJSONArray("content").getJSONObject(0).getString("text");
  return raw;
}



// Colour from the emotion, as the system prompt asks the LLM to do:
// base hue per emotion, intensity (saturation / brightness) varies
float[] EMOTION_HUES = emotionHues();   // from EMOTION_COLORS (Colors.pde)

String emotionHex(int emotion, float hueJitter, float sat, float bri) {
  float h = (EMOTION_HUES[constrain(emotion, 1, 7) - 1] + hueJitter + 360) % 360;
  return "#" + hex(color(h, sat, bri), 6);
}

// Test mode: truly random parameters, shown on the main wall
void generateTestWord(String word) {
  JSONObject out = new JSONObject();
  out.setString("word",            word);
  out.setInt("emotion",            int(random(1, 8)));
  out.setInt("word_class",         int(random(1, 9)));
  out.setInt("abstraction",        int(random(1, 8)));
  out.setInt("agency",             int(random(1, 8)));
  out.setInt("organic",            int(random(1, 8)));
  out.setInt("phenomena_class",    int(random(1, 8)));
  out.setInt("time_duration",      int(random(1, 8)));
  out.setString("color_hex",       emotionHex(out.getInt("emotion"), random(-12, 12), random(45, 95), random(55, 100)));
  out.setInt("culturalitat",       int(random(1, 8)));
  out.setInt("raresa",             int(random(1, 8)));
  saveJSONObject(out, "data/input.json");
  loadJSONFromPath(jsonPath);
  displayText = "TEST  phenomenon " + out.getInt("phenomena_class")
              + " · abstraction " + out.getInt("abstraction")
              + " · organic "     + out.getInt("organic")
              + " · agency "      + out.getInt("agency")
              + " · time "        + out.getInt("time_duration")
              + " · emotion "     + out.getInt("emotion")
              + " · class "       + out.getInt("word_class")
              + " · cult "        + out.getInt("culturalitat")
              + " · rare "        + out.getInt("raresa")
              + " · mode test (no LLM)"
              + " · "             + out.getString("color_hex");
  println("Test params for '" + word + "': " + displayText);
}

// Without API key: parameters derived from the word itself,
// so the same word always gives the same tile.
void generateRandomWord(String word) {
  Random r = new Random(wordSeed(word));
  JSONObject out = new JSONObject();
  out.setString("word",            word);
  out.setInt("emotion",            1 + r.nextInt(7));
  out.setInt("word_class",         1 + r.nextInt(8));
  out.setInt("abstraction",        1 + r.nextInt(7));
  out.setInt("agency",             1 + r.nextInt(7));
  out.setInt("organic",            1 + r.nextInt(7));
  out.setInt("phenomena_class",    1 + r.nextInt(7));
  out.setInt("time_duration",      1 + r.nextInt(7));
  out.setString("color_hex",       emotionHex(out.getInt("emotion"), rnd(r, -12, 12), rnd(r, 45, 95), rnd(r, 55, 100)));
  out.setInt("culturalitat",       1 + r.nextInt(7));
  out.setInt("raresa",             1 + r.nextInt(7));
  saveJSONObject(out, "data/input.json");
  loadJSONFromPath(jsonPath);
  println("Params generated for: " + word + " (cult " + out.getInt("culturalitat") + ", rare " + out.getInt("raresa") + ")");
}
