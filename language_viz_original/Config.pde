// ═══════════════════════════════════════════════════════════
// Config.pde
// Global variables and shared utilities.
// ═══════════════════════════════════════════════════════════

// ── SOUND ───────────────────────────────────────────────────
final String MIDI_PORT = "processing (A)";
//final String MIDI_PORT = "Bus 1";
int CH_LEAD  = 1;

// ── LLM API CONFIG ───────────────────────────────────────────────────
final String API_KEY     = "";  // ← your key
final String MODEL       = "claude-haiku-4-5-20251001";
final String prompt_path = "prompts/haiku_art_system_prompt.md";
String SYSTEM_PROMPT;

// Central word parameters -> updated by JSONLoader
int pEmotion    = 1;
int pWordClass  = 1;
int pAbstract   = 4;
int pAgency     = 4;
int pOrganic    = 4;
int pPhenomenon = 1;
int pTime       = 4;
color pColorHex  = color(255, 165, 0);
String currentWord = "—";


// Animation time 
float t = 0;

// Poem system 
int MAX_POEM_WORDS      = 4;
int POEM_SPAWN_INTERVAL = 30; // frames between poem word spawns

// Glow particles 
int MAX_GLOW = 180;
int glowT    = 0;

// ****************
// Shared utilities
// ****************

//Convert from HEX to HSB color mode
color parseHexColor(String hex) {
  hex = hex.trim();
  if (hex.startsWith("#")) hex = hex.substring(1);
  if (hex.length() != 6) return color(255, 165, 0);
  int r = unhex(hex.substring(0, 2));
  int g = unhex(hex.substring(2, 4));
  int b = unhex(hex.substring(4, 6));
  colorMode(RGB, 255);
  color rgb = color(r, g, b);
  colorMode(HSB, 360, 100, 100, 100);
  return color(hue(rgb), saturation(rgb), brightness(rgb));
}

// Lerp between two hues respecting circular 0-360 wrap
float lerpAngle(float a, float b, float amt) {
  float diff = b - a;
  if (diff >  180) diff -= 360;
  if (diff < -180) diff += 360;
  return (a + diff * amt + 360) % 360;
}
