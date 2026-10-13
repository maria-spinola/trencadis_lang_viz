
// ════════════════════════════════════════════════════════════════
//  API CALL  —  runs on a background thread so draw() never blocks
// ════════════════════════════════════════════════════════════════

// LLM_PROVIDER "ollama": local (Salamandra / Ollama) / cloud / auto (LLM_MODE, CatalanLLM.pde), on a background thread
void callModel(String word) {
  isLoading = true;
  final String w = word;
  new Thread(() -> {
    try {
      String[] r = askModelChain(w);
      llmModeUsed = r[1];
      responseRaw = r[0];
    } catch (Exception e) {
      responseRaw = "{\"connection_error\":\"" + escapeJson(msgOf(e)) + "\"}";
    }
  }).start();
}

void callClaude(String userInput) {
  isLoading = true;
  final String prompt = userInput;

  new Thread(() -> {
    try {
      String body = buildRequestJSON(prompt);

      HttpClient client = HttpClient.newHttpClient();

      HttpRequest req = HttpRequest.newBuilder()
        .uri(URI.create("https://api.anthropic.com/v1/messages"))
        .header("Content-Type",      "application/json; charset=utf-8")
        .header("x-api-key",         API_KEY)
        .header("anthropic-version", "2023-06-01")
        // ⚠️  temperature is a BODY parameter, not an HTTP header.
        //     It belongs in buildRequestJSON() in Utils.pde — moved there.
        .POST(HttpRequest.BodyPublishers.ofString(body, java.nio.charset.StandardCharsets.UTF_8))
        .build();

      HttpResponse<String> res = client.send(req, HttpResponse.BodyHandlers.ofString(java.nio.charset.StandardCharsets.UTF_8));
      responseRaw = res.body();

    } catch (Exception e) {
      responseRaw = "{\"connection_error\":\"" + escapeJson(e.getMessage()) + "\"}";
    }

  }).start();
}
