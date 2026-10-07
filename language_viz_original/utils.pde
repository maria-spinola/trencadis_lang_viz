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

void saveResponse(String responseText) {
  try {
    String cleaned = responseText.trim()
      .replaceAll("(?s)^```json\\s*", "")
      .replaceAll("(?s)\\s*```$",    "")
      .trim();

    JSONObject out = parseJSONObject(cleaned);
    saveJSONObject(out, "data/input.json");
    println("Saved response to data/input.json");

  } catch (Exception e) {
    println("ERROR saving response: " + e.getMessage());
  }
}


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

    // ── Packed connection error from callClaude() catch block
    if (json.hasKey("connection_error")) {
      displayText = "Connection error: " + json.getString("connection_error");
      return;
    }

    // ── Anthropic API error  {"error": {"type": "...", "message": "..."}}
    if (json.hasKey("error")) {
      JSONObject err = json.getJSONObject("error");
      displayText = "API error: " + err.getString("message");
      return;
    }

    // ── Success  {"content": [{"type": "text", "text": "..."}], ...}
    JSONArray  content = json.getJSONArray("content");
    JSONObject block   = content.getJSONObject(0);
    String responseText = block.getString("text");
    displayText = "";   // clear any previous error message

    // Write data/input.json, then immediately trigger particle update.
    // Direct call bypasses the file-watcher's first-run blind spot
    // (lastModified==0 would prevent detecting the very first write).
    saveResponse(responseText);
    loadJSONFromPath(jsonPath);

  } catch (Exception e) {
    displayText = "Parse error: " + e.getMessage();
  }
}



void generateRandomWord(String word) {
  JSONObject out = new JSONObject();
  out.setString("word",            word);
  out.setInt("emotion",            int(random(1, 8)));
  out.setInt("word_class",         int(random(1, 9)));
  out.setInt("abstraction",        int(random(1, 8)));
  out.setInt("agency",             int(random(1, 8)));
  out.setInt("organic",            int(random(1, 8)));
  out.setInt("phenomena_class",    int(random(1, 8)));
  out.setInt("time_duration",      int(random(1, 8)));
  out.setString("color_hex",       randomHex());
  saveJSONObject(out, "data/input.json");
  loadJSONFromPath(jsonPath);
  println("Random params generated for: " + word);
}

String randomHex() {
  return String.format("#%02X%02X%02X",
    int(random(256)),
    int(random(256)),
    int(random(256)));
}
