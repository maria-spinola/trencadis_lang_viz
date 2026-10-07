# Trencadís Language Visualizer
**MDACT Project — 1st Block**

An immersive installation made with Processing: every word typed by a visitor becomes a **tile of a Catalan *trencadís*** — the broken-ceramic mosaic of Gaudí's Park Güell — shaped by its meaning. The tile assembles on the main wall, breaks apart, travels across the room and settles into a shared mural that grows with every word. Each word also plays a generative MIDI chord.

## Authors
Alberto Benavent Ramón, Francisco A. Rodríguez, Lerie Pemanagpo, María Spínola Lasso and Marta Alavedra Marion

### Inspiration
- Gaudí's *trencadís* in Park Güell, Barcelona.
- The first, particle-based version of the project was inspired by *Genuary2026_16: Order and disorder* by KaitoFMS and *260401 Particles* by Vivian.

---

## How it works

1. **A word comes in.** A visitor types a word on the main wall (WALL 3). An LLM (Claude) describes it with 7 semantic parameters and a colour (`data/input.json`).
2. **It becomes a tile.** A decorated ceramic tile is painted from those parameters and broken into irregular straight-edged shards, as in real trencadís.
3. **It assembles on WALL 3.** The shards come from far behind the wall — dark and out of focus — and become sharp as they reach their place, the small ones first.
4. **It travels.** The tile comes apart and its pieces travel as a loose cloud — round by WALL 2, round by WALL 4 or across the floor — to the tile's slot on WALL 1. Optionally they fly through the air of the room in 3D.
5. **It settles.** The pieces close up in the slot, the grout seeps in under them and dries, and the tile stays in the mural.

Over the exhibition WALL 1 fills up with a wavy mosaic made of all the visitors' words. Words of a poem (`poem_words.json`) float through the room as small tiles.

### Deterministic
Every tile comes from a seed made of the word, its colour and its parameters. The same word with the same parameters always gives the same tile, and the same words in the same order always give the same mural. Without an API key the parameters themselves are derived from the word.

---

## The room

The room is a box: four walls and the floor. The sketch renders each surface separately and packs them into one image laid out like the venue's **media matrix** (unfolded box):

```
              ┌──────────┐
              │  WALL 2  │
   ┌──────────┼──────────┼──────────┐
   │  WALL 1  │  FLOOR   │  WALL 3  │   ← WALL 3 = main wall (text input)
   └──────────┼──────────┼──────────┘
              │  WALL 4  │
              └──────────┘
```

Each wall touches the floor with its bottom edge. Everything is drawn on the surfaces themselves, so shapes continue across corners and look right from anywhere in the room (except the optional 3D travel, see below).

---

## The 7 parameters → visuals

| Parameter | Range | Visual effect |
|---|---|---|
| `phenomena_class` | 1–7 | **The painted motif and how the tile breaks** (see below) |
| `abstraction` | 1–7 | Shard size: 1 = small shards and small motifs, 7 = big, simple shards |
| `organic` | 1–7 | How crooked the cracks are, how much the pieces wave on their way |
| `agency` | 1–7 | Speed: how fast the tile assembles and travels |
| `time_duration` | 1–7 | How long the tile stays still on WALL 3 before leaving |
| `word_class` | 1–8 | How the shards come in while the tile assembles (see below) |
| `emotion` | 1–7 | The colour (the LLM picks `color_hex` from the emotion) and how the travelling pieces split between routes (see below) |
| `color_hex` | `#RRGGBB` | The palette: base, warm light, dark, an accent (complementary or neighbouring hue) and ochre |

The shape depends on the phenomenon, not on the word class, because visitors mostly type nouns. Colours are kept to ceramic glazes (saturation and brightness are capped).

### Phenomenon → motif and breakage

| Value | Phenomenon | Painted motif | Breakage |
|---|---|---|---|
| 1 | Static | Plain shards in tones of one colour | clean |
| 2 | Soft dispersion | Plain shards of several colours mixed (classic trencadís) | very chipped |
| 3 | Spiral deformation | Spiral bands winding out from an off-centre point | medium |
| 4 | Noisy sub-clusters | Scattered flowers and leaves | medium |
| 5 | High-frequency vibration | Fine geometric tilework: diamonds, small squares, dark corners | the most chipped |
| 6 | Directional drift | Arabesque wave bands with little leaves | crooked |
| 7 | Three groupings | Bold two-colour checker of triangles | clean |

The tile is broken like real ceramic: straight cracks cut the biggest pieces again and again, some areas are crushed into small chips, and some pieces lose a corner — so shards have 3 to 7 sides and irregular angles. Each shard is set back slightly off, so the motif is cut by the cracks. Every tile also has a ribbon of dark pieces along its top edge; on WALL 1 each band has its own ribbon tone, which draws the wavy lines of the mural.

### Word class → how the shards come in

All shards come from far behind WALL 3, scattered, dark and out of focus, and become sharp and lit as they reach their place — small ones first, the big ones at the back last. The word class sets their path:

| Value | Class | Entrance |
|---|---|---|
| 1 | Noun | Gather from a ring all around the tile |
| 2 | Verb | Sweep in from the left |
| 3 | Adjective | Appear in place, growing out of nothing |
| 4 | Adverb | Swirl in around the centre |
| 5 | Preposition | From above and below, meeting in the middle |
| 6 | Determiner | Burst out of the centre |
| 7 | Pronoun | Straight out of the depth, turning |
| 8 | Conjunction | From the left and the right, joining |

### Emotion → the journey

When it leaves WALL 3 the tile comes apart: every piece travels on its own, leaving in turn, drifting into a loose cloud and turning a little, and they all close up again in the slot on WALL 1. The emotion decides how the cloud splits:

| Emotion | Routes |
|---|---|
| Love, Sadness | keeps together: WALL 2, WALL 4 or the floor |
| Joy, Surprise | splits in two: usually WALL 2 + WALL 4, sometimes one wall + the floor |
| Anger, Fear, Disgust | splits in three: WALL 2 + WALL 4 + the floor |

The left part of the tile goes round by WALL 2, the right part by WALL 4, the lowest part across the floor (turning round to arrive upright).

### 2D or 3D travel (`TRAVEL_3D`, Ctrl+D)

- **2D (default):** the pieces slide along the walls and the floor. Looks right from anywhere in the room.
- **3D:** the pieces leave WALL 3 into the room and fly through the air, each at its own depth (on the WALL 2 side, the WALL 4 side or low over the floor), and land on WALL 1. Each surface is rendered from the audience's point of view — centre of the room, eye height `VIEWER_HEIGHT` — with an off-axis projection (a virtual camera rig, `viewerCamera()` in `Room.pde`), so the pieces line up across walls and floor. The illusion is perfect from that point and more distorted further away. Pieces stay below eye level: anything higher would be projected towards the ceiling, where nothing is shown.

### The mural (WALL 1)

- WALL 1 is divided once (`MOSAIC_SEED`) into wavy bands (`MOSAIC_ROWS`) of straight-edged cells; the waves are faceted. With the defaults there are 69 cells. They fill from the centre outwards; when the wall is full new tiles cover the oldest.
- The grout (thin grey cement) only appears when a tile lands: it seeps in under the shards, dark and wet, and dries to its final colour.
- The mural is saved in `data/mosaic.json` and restored on start. `Ctrl+N` clears it.

---

## Project structure

```
language_viz/
├── language_viz.pde      — Main sketch: setup, draw, keyboard
├── Config.pde            — All settings (room, output, mosaic, timing, LLM, sound…)
├── Room.pde              — Walls + floor, media matrix, cameras (flat, main wall, 3D viewer), preview, calibration
├── Trencadis.pde         — A tile: palette, painted motifs, breaking into shards, drawing, assembly
├── Mosaic.pde            — WALL 1 mural (slots, saving) and each tile's journey (assemble → travel → set)
├── Output.pde            — Output images for PIXERA: media matrix or groups of surfaces; windows / Syphon / Spout
├── WordsSystem.pde       — Poem words floating as small tiles
├── ClaudeSketch.pde      — Text input on the main wall, API state
├── ai_agent.pde          — Anthropic API call (background thread)
├── utils.pde             — Request builder, response parsing, test-mode / no-API parameters
├── JSONLoader.pde        — Reads input.json (and watches it for changes)
├── SoundEngine.pde       — MIDI chord generation entry point
├── MidiController.pde    — Low-level MIDI output via themidibus
├── ChordBuilder.pde      — Maps parameters to MIDI notes
├── JSONParser.pde        — Helper to trigger sound from a raw JSON string (testing)
├── miditest.pde          — MIDI test sketch (commented out)
├── data/
│   ├── input.json        — Current word and its parameters
│   ├── poem_words.json   — Poem words with parameters
│   └── mosaic.json       — The mural (created automatically, not in git)
├── prompts/
│   └── haiku_art_system_prompt.md — System prompt sent to Claude
└── Reaper/
    └── miditest.rpp      — Reaper project for the sound
language_viz_original/    — Earlier version of the sketch (particles, single screen)
```

---

## Setup

### Requirements
- [Processing 4](https://processing.org/download)
- Library **themidibus** (Processing's Library Manager)
- Optional: an Anthropic API key (for the LLM), Reaper or any MIDI app (for the sound), Syphon / Spout (to send the image to PIXERA)

### Running
1. Open `language_viz/language_viz.pde` in Processing.
2. Optional: put your API key in `Config.pde` (`API_KEY`). **Never commit it.**
3. Run. Type a word and press Enter.

### Typing words
The text box is centred on WALL 3, below the tile. Type a word and press Enter.
- **With API key:** Claude analyses the word and returns the parameters (`temperature 0`), saved to `data/input.json`.
- **Without API key:** the parameters are derived from the word itself (always the same for the same word); the colour follows the emotion as the LLM would.
- **Test mode (`Ctrl+E`):** words skip the LLM and get random parameters, shown on screen. Test tiles are not saved; leaving test mode brings back the real mural.

The model and prompt are set in `Config.pde`:
```java
final String MODEL       = "claude-haiku-4-5-20251001";
final String prompt_path = "prompts/haiku_art_system_prompt.md";
```

---

## Main settings (`Config.pde`)

| Setting | What it does |
|---|---|
| `ROOM_W`, `ROOM_D`, `WALL_H` | Room size in media matrix units (now 4250 × 4300 × 1200 → 6650 × 6700 matrix) |
| `RENDER_SCALE` | Output pixels per matrix unit: 1.0 = native venue resolution; 0.5 for a laptop |
| `MAIN_FACE` | The main wall (text input) |
| `OUTPUT_GROUPS`, `OUTPUT_WINDOWS`, `OUTPUT_DISPLAYS` | How the image leaves Processing (see below) |
| `TRAVEL_3D`, `VIEWER_HEIGHT`, `DEPTH_3D` | 2D / 3D travel, audience eye height, how deep into the room |
| `HOLD_HEIGHT`, `HOLD_Y` | Size and height of the tile on WALL 3 |
| `ASSEMBLE_DEPTH`, `ASSEMBLE_SPREAD` | How far and how scattered the shards come from |
| `ASSEMBLE_FRAMES_*`, `HOLD_FRAMES_*` | Time assembling / still on WALL 3 |
| `SCATTER` | How far apart the pieces drift while travelling (0 = the tile travels whole) |
| `MOSAIC_ROWS`, `MOSAIC_SEED`, `MOSAIC_SAVE` | Mural layout and saving |
| `GROUT_*`, `GROUT_SET_FRAMES`, `GLAZE` | Grout width / colour / setting time, glaze sheen |
| `TEXTURE_DETAIL` | Resolution of the painted motifs |
| `UI_WIDTH`, `UI_Y`, `UI_SCALE`, `UI_BAR_ALPHA` | The text box |
| `SHOW_POEM` | Floating poem tiles on / off |
| `TEST_MODE` | Start in test mode |
| `API_KEY`, `MODEL`, `MIDI_PORT` | LLM and sound |

---

## Venues (`VENUE` in `Config.pde`)

| `VENUE` | Room | Surfaces | Default output |
|---|---|---|---|
| `0` | Florida media matrix (PIXERA) | 4 walls + floor, 6650 × 6700 matrix | the media matrix |
| `1` | La Salle IASLab immersive room (Watchout, real time via NDI) | 4 walls, **no floor**: FRONT / BACK 3206 × 1200, LEFT / RIGHT 4966 × 1200 | one strip 16344 × 1200: FRONT \| RIGHT \| BACK \| LEFT |

In the IASLab, FRONT is the main wall (text input and assembling), BACK holds the mural, and the pieces travel along LEFT and RIGHT. With no floor, the floor is not rendered, pieces never travel over it (in 3D they fly around eye level so they are seen on the walls), and the floating poem tiles stay on the walls. The audience eye height is set to 1.6 m of the 2.7 m projected height.

## Output to the room (PIXERA)

The whole room is always composed as one image laid out like the media matrix (`matrixOut`). If the venue wants it split, `OUTPUT_GROUPS` makes one image per group of surfaces, side by side, upright, in the order written:

```java
int[][] OUTPUT_GROUPS = {};                                   // only the media matrix
int[][] OUTPUT_GROUPS = { {W1, W2}, {W3, W4}, {FLOOR} };      // 2 + 2 + 1
int[][] OUTPUT_GROUPS = { {W1, W2}, {W3, W4, FLOOR} };        // 2 + 3
int[][] OUTPUT_GROUPS = { {W1}, {W2}, {W3}, {W4}, {FLOOR} };  // one per surface
```

Sending them out (`Output.pde`):
- **Syphon (macOS) / Spout (Windows)** — the efficient way when PIXERA runs on the same computer: install the library and uncomment the lines marked `SYPHON` or `SPOUT` in `Output.pde` and `language_viz.pde`. Each output appears in PIXERA as "language_viz 1", "language_viz 2"…
- **Windows** — `OUTPUT_WINDOWS = true` opens each output in its own window, full screen on the display set in `OUTPUT_DISPLAYS`. No library needed, but every frame is copied through the CPU (much slower).
- If PIXERA runs on another computer, use NDI or a video output / capture card.

### In the venue
1. Set `ROOM_W`, `ROOM_D`, `WALL_H` to the venue's media matrix and `RENDER_SCALE` to what the machine can hold (check the fps).
2. Press `Ctrl+T`: every surface shows its name, a grid and, on each edge, what should be on the other side ("↑ TECHO", "↓ FLOOR", "WALL 2"…). Walk the room and check. If a wall is rotated, change only its rotation in `setupRoom()` (`Room.pde`).
3. Check that the grid squares are the same size on every surface (same pixel density).
4. Send a few words, in 2D and 3D, and watch them cross the corners.
5. Before opening: `Ctrl+N` to clear the test mural, test mode off. The Processing window must keep the keyboard focus.

---

## Keys

All shortcuts use **Ctrl** (or **Cmd** on Mac), so typing words never triggers them.

| Key | Action |
|---|---|
| `Ctrl+V` | Preview: media matrix → FLOOR → WALL 1 → WALL 2 → WALL 3 → WALL 4 → output images |
| `Ctrl+T` | Calibration pattern (in the output) |
| `Ctrl+L` | Surface outlines in the preview |
| `Ctrl+D` | Travel in 2D (along the surfaces) or 3D (through the air of the room) |
| `Ctrl+E` | Test mode (random parameters, nothing saved) |
| `Ctrl+P` | Floating poem tiles on / off |
| `Ctrl+N` | Clear the mural on WALL 1 (no confirmation) |
| `Ctrl+R` | Reload `input.json` (adds that word again) |
| `Ctrl+U` | Hide / show the text box |
| `Ctrl+3` | Tile on WALL 3: gentle 3D sway (default) |
| `Ctrl+2` | Tile on WALL 3: flat, no movement |
| `Ctrl+G` | Tile on WALL 3: full spin |
| `Ctrl+M` | Tile on WALL 3: drag with the mouse to rotate it |

---

## JSON format

### `input.json` (current word)
```json
{
  "word": "mariposa",
  "emotion": 7,
  "emotion_label": "Joy / Happiness",
  "color_hex": "#FFA500",
  "word_class": 1,
  "abstraction": 4,
  "agency": 5,
  "organic": 2,
  "phenomena_class": 1,
  "time_duration": 5
}
```

### `poem_words.json`
```json
{
  "poem": "All Watched Over by Machines of Loving Grace",
  "author": "Richard Brautigan",
  "words": [
    {
      "word": "grace",
      "color_hex": "#FFD700",
      "word_class": 1,
      "abstraction": 6,
      "agency": 4,
      "organic": 5,
      "phenomena_class": 3,
      "time_duration": 7
    }
  ]
}
```

---

## Sound engine

Each word plays an arpeggiated chord over MIDI:

| Parameter | Sound |
|---|---|
| `emotion` | Chord quality (anger, surprise, fear, love, disgust, sadness, joy) |
| `word_class` | Chord degree (root note in C major) |
| `abstraction` | Time between the notes of the arpeggio |
| `agency` | Velocity |
| `organic` | Octave |
| `phenomena_class` | MIDI channel (1–7) |
| `time_duration` | Note duration |

Set `MIDI_PORT` in `Config.pde` to the name of your MIDI loopback (on Windows, use *Windows MIDI and Musician Settings*: third-party loopback programs no longer work). Run the Reaper project (`Reaper/miditest.rpp`), or any MIDI app listening on channels 1–7, to hear it.
