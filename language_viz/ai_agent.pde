
// ════════════════════════════════════════════════════════════════
//  API CALL  —  runs on a background thread so draw() never blocks
// ════════════════════════════════════════════════════════════════

void callClaude(String userInput) {
  isLoading = true;
  final String prompt = userInput;

  new Thread(() -> {
    try {
      String body = buildRequestJSON(prompt);

      HttpClient client = HttpClient.newHttpClient();

      HttpRequest req = HttpRequest.newBuilder()
        .uri(URI.create("https://api.anthropic.com/v1/messages"))
        .header("Content-Type",      "application/json")
        .header("x-api-key",         API_KEY)
        .header("anthropic-version", "2023-06-01")
        // ⚠️  temperature is a BODY parameter, not an HTTP header.
        //     It belongs in buildRequestJSON() in Utils.pde — moved there.
        .POST(HttpRequest.BodyPublishers.ofString(body))
        .build();

      HttpResponse<String> res = client.send(req, HttpResponse.BodyHandlers.ofString());
      responseRaw = res.body();

    } catch (Exception e) {
      responseRaw = "{\"connection_error\":\"" + escapeJson(e.getMessage()) + "\"}";
    }

  }).start();
}
