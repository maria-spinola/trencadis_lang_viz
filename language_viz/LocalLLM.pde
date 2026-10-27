// ════════════════════════════════════════════════════════════════
// LocalLLM.pde
// The local model: Qwen3.5 2B Instruct (LLAMA_MODEL_FILE; it was Salamandra 7B, too slow), run by
// llama.cpp's llama-server. The sketch starts the server when it opens and stops it
// on exit (LLAMA_AUTOSTART); one already running on LLAMA_PORT is reused.
//
// The request goes in two steps, not through /v1/chat/completions:
//   1. /apply-template — the conversation, written with the model's own chat template
//   2. /completion     — the answer, forced to our JSON schema (twoShapeSchema, CatalanLLM.pde)
// (In llama.cpp b11429 a JSON schema on /v1/chat/completions fails with this model:
// "Failed to initialize samplers" — the grammar includes the template's <|im_start|>.)
//
// The model's own chat template places the instructions (a system role, or the first user message
// for models without one). The examples of the prompt go as real turns (word → JSON): written
// inside the instructions, small models copy the first one for most words.
// Qwen3.5 thinks before answering by default: chat_template_kwargs enable_thinking=false skips it
// (models without thinking ignore it).
// ════════════════════════════════════════════════════════════════

ProcessHandle llamaProc;               // the server the sketch started or adopted (null = not ours)
volatile String llamaState = "off";    // off · starting · ready · failed
String llamaWhy = "";                  // why it isn't ready (shown when a word falls back)

String llamaURL(String path) { return "http://127.0.0.1:" + LLAMA_PORT + path; }

boolean usesLlama() { return !LLM_MODE.equals("cloud") && LOCAL_ENGINE.equals("llamacpp"); }

// Name of the local model, for the console
String localModelName() {
  return LOCAL_ENGINE.equals("llamacpp") ? new File(LLAMA_MODEL_FILE).getName() + " (llama.cpp)" : OLLAMA_MODEL_LOCAL + " (ollama)";
}

// ── Switching while running (Ctrl+O) ──────────────────────────────

String[] LLM_MODES = { "auto", "cloud", "local" };

void cycleLLMMode() {
  int i = 0;
  while (i < LLM_MODES.length && !LLM_MODES[i].equals(LLM_MODE)) i++;
  LLM_MODE = LLM_MODES[(i + 1) % LLM_MODES.length];
  llmStatusFrame = -999;   // show the new mode at once
  println("Model mode: " + LLM_MODE + "  (" + llmStatusNow() + ")");
  if (LLM_PROVIDER.equals("ollama")) startLlamaServer();   // local / auto: start it if it isn't running (kept running in cloud mode)
}

// For the preview window: which mode, and whether each side can answer (refreshed once a second:
// it reads the key file)
String llmStatusText = "";
int llmStatusFrame = -999;

String llmStatus() {
  if (frameCount - llmStatusFrame >= 60) { llmStatusText = llmStatusNow(); llmStatusFrame = frameCount; }
  return llmStatusText;
}

String llmStatusNow() {
  if (!LLM_PROVIDER.equals("ollama")) return "model " + LLM_PROVIDER;
  String local = LOCAL_ENGINE.equals("llamacpp") ? new File(LLAMA_MODEL_FILE).getName().replace(".gguf", "") + " " + llamaState : "ollama " + OLLAMA_MODEL_LOCAL;
  String cloud = OLLAMA_MODEL_CLOUD + (ollamaKey().length() > 0 ? "" : " (no key)");
  if (LLM_MODE.equals("cloud")) return "model: cloud " + cloud;
  if (LLM_MODE.equals("local")) return "model: local " + local;
  return AUTO_CLOUD_FIRST ? "model: auto · cloud " + cloud + ", else " + local : "model: auto · " + local + ", else " + cloud;
}

// ── Starting and stopping the server ──────────────────────────────

// Called from setupLLM() and when Ctrl+O switches to a mode that uses it: starts the server
// on a background thread, then warms it up. Also retries after a failure.
void startLlamaServer() {
  if (!usesLlama() || llamaState.equals("starting") || llamaState.equals("ready")) return;
  llamaState = "starting";
  new Thread(() -> {
    if (llamaHealth() == 200) {
      llamaProc = findOurLlamaServer();   // left behind by a crash: adopted, so this run stops it on exit
      if (llamaProc != null) Runtime.getRuntime().addShutdownHook(new Thread(() -> stopLlamaServer()));
      println("Local model: llama-server already running on port " + LLAMA_PORT + ", reused"
        + (llamaProc != null ? " (left by a previous run; stopped on exit)" : " (not started by this sketch; left running on exit)"));
    } else if (!LLAMA_AUTOSTART) {
      llamaFailed("llama-server is not running on port " + LLAMA_PORT + " (LLAMA_AUTOSTART is off)");
      return;
    } else {
      String bin = findLlamaServer();
      File model = new File(sketchPath(LLAMA_MODEL_FILE));
      if (bin == null)     { llamaFailed("llama-server not found → run setup_mac.command / setup_windows.bat"); return; }
      if (!model.exists()) { llamaFailed("model missing: " + LLAMA_MODEL_FILE + " → run setup_mac.command / setup_windows.bat"); return; }
      // GPU first; if it dies (Vulkan driver, not enough video memory…), the same program on the CPU,
      // then the CPU-only build next to the sketch (llama.cpp-cpu) — slower, but it always runs
      boolean up = launchLlama(bin, model, true);
      if (!up) up = launchLlama(bin, model, false);
      String cpu = findInDirs(new String[] { sketchPath("llama.cpp-cpu"), sketchPath("../llama.cpp-cpu") });
      if (!up && cpu != null && !cpu.equals(bin)) up = launchLlama(cpu, model, false);
      if (!up) {
        llamaFailed("llama-server did not start (see data/llama_server.log)");
        return;
      }
    }
    llamaState = "ready";
    llamaWarmUp();
  }).start();
}

// One try at starting llama-server: true when it answers. A server still loading the model (a slow disk,
// the GPU's first run) is given up to 3 × LLAMA_START_S; one that exits is reported with the end of its log.
boolean launchLlama(String bin, File model, boolean gpu) {
  try {
    ProcessBuilder pb = new ProcessBuilder(bin, "-m", model.getAbsolutePath(),
      "--host", "127.0.0.1", "--port", "" + LLAMA_PORT,
      "-c", "" + LLAMA_CTX,     // context: prompt + examples + word + answer; the default (160k) would take GBs
      "-np", "1",               // one word at a time
      "-ngl", gpu ? "99" : "0", // the whole model on the GPU, or none of it
      "--temp", "0", "--repeat-penalty", "1.0",   // the same word always gives the same answer (the same tile)
      "--no-webui");
    if (!gpu) pb.command().addAll(java.util.Arrays.asList("--device", "none"));
    pb.redirectErrorStream(true);
    pb.redirectOutput(new File(dataPath("llama_server.log")));
    llamaProc = pb.start().toHandle();
    if (!llamaHook) { llamaHook = true; Runtime.getRuntime().addShutdownHook(new Thread(() -> stopLlamaServer())); }
    println("Local model: starting llama-server with " + model.getName() + (gpu ? " on the GPU" : " on the CPU") + "… (" + bin + ", log: data/llama_server.log)");
  } catch (Exception e) {
    println("Local model: could not start " + bin + ": " + msgOf(e));
    return false;
  }
  for (int i = 0; i < 3; i++) {
    if (waitForLlama(LLAMA_START_S)) return true;
    if (llamaProc == null || !llamaProc.isAlive()) break;
    println("Local model: still loading…");
  }
  println("Local model: llama-server " + (gpu ? "on the GPU " : "on the CPU ") + "failed. End of data/llama_server.log:");
  String[] log = loadStrings(dataPath("llama_server.log"));
  if (log != null) for (int i = max(0, log.length - 12); i < log.length; i++) if (log[i].trim().length() > 0) println("  | " + log[i]);
  stopLlamaServer();
  return false;
}
boolean llamaHook = false;

void llamaFailed(String why) {
  llamaState = "failed";
  llamaWhy = why;
  println("Local model not available: " + why + (LLM_MODE.equals("auto") ? (AUTO_CLOUD_FIRST ? " — no fallback if the cloud fails" : " — words go to the cloud") : ""));
}

// Called from dispose() and on JVM exit. Only stops a server the sketch started (or adopted).
// If the sketch is killed outright (crash, force quit) the server stays; the next run adopts it.
synchronized void stopLlamaServer() {
  if (llamaProc == null) return;
  ProcessHandle p = llamaProc;
  llamaProc = null;
  if (!p.isAlive()) return;
  p.destroy();
  try { p.onExit().get(3, java.util.concurrent.TimeUnit.SECONDS); } catch (Exception e) { p.destroyForcibly(); }
  println("Local model: llama-server stopped");
}

// A llama-server on LLAMA_PORT with our model file: one a previous run of the sketch started
ProcessHandle findOurLlamaServer() {
  String model = new File(LLAMA_MODEL_FILE).getName(), port = "--port " + LLAMA_PORT;
  java.util.Iterator<ProcessHandle> it = ProcessHandle.allProcesses().iterator();
  while (it.hasNext()) {
    ProcessHandle h = it.next();
    String cmd = h.info().commandLine().orElse("");
    if (cmd.contains("llama-server") && cmd.contains(model) && cmd.contains(port)) return h;
  }
  return null;
}

// The llama-server program: LLAMA_SERVER as a full path, or found on the PATH / where Homebrew and winget put it.
// (Processing started from the Dock doesn't see the terminal's PATH, hence the fixed places.)
String findLlamaServer() {
  File f = new File(LLAMA_SERVER);
  if (f.isAbsolute()) return f.canExecute() ? f.getAbsolutePath() : null;
  StringList dirs = new StringList();
  String path = System.getenv("PATH");
  if (path != null) for (String d : path.split(File.pathSeparator)) dirs.append(d);
  dirs.append("/opt/homebrew/bin");
  dirs.append("/usr/local/bin");
  String local = System.getenv("LOCALAPPDATA");
  if (local != null) dirs.append(local + "\\Microsoft\\WinGet\\Links");
  dirs.append(sketchPath("llama.cpp"));      // a copy of llama.cpp next to the sketch, or next to its folder
  dirs.append(sketchPath("../llama.cpp"));   // (the room's disk carries one: no install needed)
  return findInDirs(dirs.toArray());
}
String findInDirs(String[] dirs) {
  // (the room's disk carries the Windows build: on a Mac its .exe can't run, Homebrew's llama-server is used)
  String[] names = platform == WINDOWS ? new String[] { LLAMA_SERVER, LLAMA_SERVER + ".exe" } : new String[] { LLAMA_SERVER };
  for (String d : dirs) {
    for (String name : names) {
      File c = new File(d, name);
      if (c.isFile() && c.canExecute()) return c.getAbsolutePath();
    }
  }
  return null;
}

// HTTP status of /health: 200 ready, 503 loading the model, -1 nothing listening
int llamaHealth() {
  try {
    HttpClient client = HttpClient.newBuilder().connectTimeout(java.time.Duration.ofSeconds(1)).build();
    HttpRequest req = HttpRequest.newBuilder().uri(URI.create(llamaURL("/health"))).timeout(java.time.Duration.ofSeconds(2)).GET().build();
    return client.send(req, HttpResponse.BodyHandlers.discarding()).statusCode();
  } catch (Exception e) {
    return -1;
  }
}

// Waits until the server answers /health (true), or it dies or the time runs out (false)
boolean waitForLlama(float seconds) {
  long until = System.currentTimeMillis() + (long) (seconds * 1000);
  while (System.currentTimeMillis() < until) {
    if (llamaHealth() == 200) return true;
    if (llamaProc != null && !llamaProc.isAlive()) return false;
    try { Thread.sleep(250); } catch (InterruptedException e) { return false; }
  }
  return false;
}

// As soon as the server is up, it reads the instructions and examples (~5k tokens) once, without
// answering: they stay in its cache, so the first visitor doesn't wait for them to be read
void llamaWarmUp() {
  try {
    long t = System.currentTimeMillis();
    JSONObject tpl = llamaPost("/apply-template", llamaTemplateBody("casa"), 10);
    llamaPost("/completion", "{\"prompt\":\"" + escapeJson(tpl.getString("prompt")) + "\",\"n_predict\":0,\"cache_prompt\":true}", 600);
    println("Local model ready: " + localModelName() + " · instructions read in " + nf((System.currentTimeMillis() - t) / 1000.0, 0, 1) + " s");
  } catch (Exception e) {
    println("Local model: warm-up failed (" + msgOf(e) + ")");
  }
}

// ── The request ───────────────────────────────────────────────────

// The model's answer (the JSON text) for the user message (word + definition). Throws if it can't be used.
String llamaRequest(String userMsg) throws Exception {
  if (llamaState.equals("starting") && !waitForLlama(LLAMA_START_S)) throw new Exception("llama-server still starting");
  if (llamaState.equals("failed") || llamaState.equals("off")) throw new Exception(llamaWhy.length() > 0 ? llamaWhy : "llama-server not running");
  JSONObject tpl = llamaPost("/apply-template", llamaTemplateBody(userMsg), 10);
  String body = "{"
    + "\"prompt\":\"" + escapeJson(tpl.getString("prompt")) + "\","
    + "\"temperature\":0,"
    + "\"n_predict\":400,"
    + "\"cache_prompt\":true,"
    + "\"json_schema\":" + twoShapeSchema()
    + "}";
  JSONObject res = llamaPost("/completion", body, 120);
  return res.getString("content");
}

JSONObject llamaPost(String path, String body, int timeoutS) throws Exception {
  HttpClient client = HttpClient.newBuilder().connectTimeout(java.time.Duration.ofSeconds(2)).build();
  HttpRequest req = HttpRequest.newBuilder()
    .uri(URI.create(llamaURL(path)))
    .header("Content-Type", "application/json; charset=utf-8")
    .timeout(java.time.Duration.ofSeconds(timeoutS))
    .POST(HttpRequest.BodyPublishers.ofString(body, java.nio.charset.StandardCharsets.UTF_8))
    .build();
  HttpResponse<String> res = client.send(req, HttpResponse.BodyHandlers.ofString(java.nio.charset.StandardCharsets.UTF_8));
  JSONObject j = parseJSONObject(res.body());
  if (res.statusCode() != 200 || j == null || j.hasKey("error")) {
    String m = "HTTP " + res.statusCode();
    try { m = j.getJSONObject("error").getString("message"); } catch (Exception e) { }
    throw new Exception(m);
  }
  return j;
}

// The body of /apply-template: the messages, and no thinking (Qwen3.5)
String llamaTemplateBody(String userMsg) {
  return "{\"messages\":" + llamaMessages(userMsg) + ",\"chat_template_kwargs\":{\"enable_thinking\":false}}";
}

// System prompt + the prompt's examples as turns + the word, as a JSON array of messages
String llamaMessages(String userMsg) {
  String[] parts = SYSTEM_PROMPT.split("## Exemples", 2);
  String msgs = "[{\"role\":\"system\",\"content\":\"" + escapeJson(parts[0].trim()
    + "\n\nCada missatge és una paraula (de vegades amb la seva definició). Respon només amb l'objecte JSON.") + "\"}";
  if (parts.length > 1) {
    // "word →" on one line, its JSON on the next
    java.util.regex.Matcher m = java.util.regex.Pattern.compile("(?m)^(.+?) →\\R(\\{.*\\})$").matcher(parts[1]);
    while (m.find()) {
      JSONObject ex = parseJSONObject(m.group(2));
      if (ex == null) continue;
      msgs += ",{\"role\":\"user\",\"content\":\"" + escapeJson(m.group(1).trim()) + "\"}"
            + ",{\"role\":\"assistant\",\"content\":\"" + escapeJson(orderedJSON(ex)) + "\"}";
    }
  }
  return msgs + ",{\"role\":\"user\",\"content\":\"" + escapeJson(userMsg) + "\"}]";
}

// An example answer the way the schema forces it (twoShapeSchema): fields in ANSWER_FIELDS order,
// a rejection only with es_catala and motiu, an accepted word without motiu
String orderedJSON(JSONObject j) {
  boolean ok = j.getBoolean("es_catala", true);
  String s = "";
  for (String k : ANSWER_FIELDS) {
    if (!j.hasKey(k)) continue;
    if (ok ? k.equals("motiu") : !(k.equals("es_catala") || k.equals("motiu"))) continue;
    Object v = j.get(k);
    s += (s.length() > 0 ? ", " : "") + "\"" + k + "\": " + (v instanceof String ? "\"" + escapeJson((String) v) + "\"" : v);
  }
  return "{" + s + "}";
}
