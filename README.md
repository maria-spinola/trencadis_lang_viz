# Trencadís Language Visualizer
**MDACT Project — 1st Block**

An immersive installation made with Processing: every word typed by a visitor becomes a **tile of a Catalan *trencadís*** — the broken-ceramic mosaic of Gaudí's Park Güell — shaped by its meaning. The tile assembles on the main wall, breaks apart, travels across the room and settles into a shared mural that grows with every word. Each word also plays a generative MIDI chord.

## Authors
Alberto Benavent Ramón, Francisco A. Rodríguez, Lerie Pemanagpo, María Spínola Lasso and Marta Alavedra Marion

### Inspiration
- Gaudí's *trencadís* in Park Güell, Barcelona.
- Word frequencies: [wordfreq](https://github.com/rspeer/wordfreq) (CC BY-SA 4.0); definitions: [Viquidiccionari](https://ca.wiktionary.org).
- The first, particle-based version of the project was inspired by *Genuary2026_16: Order and disorder* by KaitoFMS and *260401 Particles* by Vivian.

---

## How it works

1. **A word comes in.** A visitor types one word in Catalan on the main wall (WALL 3). The sketch looks up its meaning in the Catalan Wiktionary (Viquidiccionari), a language model (Salamandra, on this computer; Ollama Cloud as a fallback) checks it is Catalan and describes it with semantic parameters and a colour, and its rarity is measured from real Catalan texts (wordfreq) — see [Analysing a word](#analysing-a-word). The result goes to `data/input.json`.
2. **It becomes a tile.** A decorated ceramic tile is painted from those parameters and broken into irregular straight-edged shards, as in real trencadís.
3. **It assembles on WALL 3.** The shards come from far behind the wall — dark and out of focus — and become sharp as they reach their place, the small ones first.
4. **It travels.** The tile comes apart and its pieces travel as a loose cloud — round by WALL 2, round by WALL 4 or across the floor — to the tile's slot on WALL 1. Optionally they fly through the air of the room in 3D.
5. **It settles.** The pieces close up in the slot, the grout seeps in under them and dries, and the tile stays in the mural.

Over the exhibition WALL 1 fills up with a wavy mosaic made of all the visitors' words. A dark see-through window sits behind the tile while it assembles (`HOLD_PANEL_ALPHA`).

### The poem
Words of a poem — *Diversos són els homes i diverses les parles* by Salvador Espriu (`poem_words.json`) — live in the background, behind the mural and the text window:
1. Every 10 s one comes out of the depth behind the main wall, its pieces tiny, already heading for a free spot on a side wall; they grow and open on the way, each piece running ahead and falling behind the group.
2. The open cloud stops; the word appears on black in the middle and stays 2 s.
3. The **word** glides down to the floor and floats there like a leaf on water (no floor in the venue: along the low band of the side walls and the mural wall, never on the main wall).
4. The **tile** closes; its pieces vanish quickly one by one until one is left, which then shrinks, starts turning and wanders all the walls. The words stay on the floor (up to `MAX_FLOOR_WORDS`); old shards fade after `MAX_POEM_WORDS`.
**The visitors' words go to the floor too** (`TYPED_WORDS_TO_FLOOR`, venues with a floor): when a word is accepted, it drops from under the text box on WALL 3 and floats on the floor with the poem's words, near (readable) and in the same typeface.

Each poem word has its own depth (size, brightness, speed — fully opaque) and pace; the shards and floor words drift in and out of the depth, wander with changing speed, and the clouds settle anywhere on the side walls (high, low, centred, in a corner) without piling up. Up to `MAX_POEM_WORDS` at a time; beyond that the oldest slowly fades. Timings and sizes: `POEM_*` in `Config.pde`.

### Deterministic
Every tile comes from a seed made of the word, its colour and its parameters. The same word with the same parameters always gives the same tile, and the same words in the same order always give the same mural. If no model can be reached, the parameters themselves are derived from the word.

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

## The parameters → visuals

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
| `culturalitat` | 1–7 | How Catalan the thing named is → how many shards (few big ones … many small ones) and shards from other tiles in contrasting glazes |
| `raresa` | 1–7 | How rare the word is (measured) → **the size of the tile** in the mural (half a cell … two cells) and shards of golden lustre |

The shape depends on the phenomenon, not on the word class, because visitors mostly type nouns.

**Rich words are rewarded.** Rare or very Catalan words make visibly bigger and more complex tiles, so visitors notice that it's worth looking for them. Each of the two parameters has its own, readable effect (`Trencadis.pde`, `Mosaic.pde`, settings in `Config.pde`):
- **`raresa` → size of the tile.** Common words (raresa ≤ `SIZE_SMALL_MAX`, 2) take **half a cell** of the mural; normal ones a whole cell; rare ones (≥ `SIZE_BIG_MIN`, 6) **two neighbouring cells joined**. All tiles are shown at the same scale on WALL 3, so a rare word is visibly bigger there too. From raresa 4, up to `RICH_GOLD` (14 %) of the shards are *reflex daurat*, the gold lustre of Valencian ceramics; from raresa 5, up to `GLASS_SHARE` (14 %) are **coloured glass** — cobalt, emerald, amber, aqua, violet — deep and glowing where the light comes out (round bottle bottoms can be switched on with `GLASS_BOTTLES`; off by default).
- **`culturalitat` → how many shards.** At 1 a few big shards (shard size × `RICH_SHARD_SIMPLE` 1.5), at 7 many small ones (× `RICH_SHARD_RICH` 0.5), with more crushed spots; from 2, up to `RICH_ACCENT` (28 %) of the shards come from other tiles in contrasting glazes (cobalt / orange, ochre, white crockery, navy), as real trencadís mixes the pieces of many plates.

So *casa* is a small tile of a few big shards; *castellers* a normal tile of many small, mixed shards; *xiuxiuejar* a big tile with gold.

Tiles saved before these parameters existed are drawn as before.

**Palette.** Strong, contrasted glazes as on Park Güell (from photos of the benches): every colour is moved to the nearest glaze — red, terracotta, orange, ochre, olive, bottle green, turquoise, cobalt, navy — and made more saturated. Violets and indigo become cobalt, pinks red. The accent comes from the opposite family (cobalt against warm colours, orange against cool ones), with near-black outlines. The painted tiles have warm, earthy **grounds** — ivory, mustard, sand, porcelain, celadon (`GROUND_COLORS`) — the shards from other tiles include khaki, ochre-brown, mauve and teal glazes (`EARTH_COLORS`), the ribbons are the ochre, brown, khaki and green glazed capping of the benches with darker streaks (`RIBBON_COLORS`), and there are very few white crockery shards (`WHITE_SHARE`); the mortar is a darker warm grey. All in `Colors.pde`. Emotion → colour (when no model answers): anger red, surprise ochre, fear terracotta, love red, disgust bottle green, sadness cobalt, joy orange.

**Real ceramic (`Ceramic.pde`).** To look like the benches of Park Güell rather than a drawing, every tile is *baked* once, pixel by pixel, when it is made: two images (the tile set in its mortar, and the shards alone) that are then drawn as they are — cheaper than layering effects every frame. What it simulates:
- **Each shard** sits a few degrees tilted in the mortar (`SHARD_TILT_DEG`), so neighbours catch the light differently; light comes from the upper left.
- **The glaze** isn't flat glass: long gentle waves where it pooled (deeper colour in the hollows) and a faint orange peel (`UNDULATION`); it **reflects a bright sky** (`GLOSS`, colour `SKY_REFLECTION`) with a soft, uneven horizon, and a **highlight** where a surface faces the light (`SPECULAR`).
- **The edges**: a narrow rolled edge that catches the light or goes dark (`RIM_WIDTH`, `RIM_BEND`); broken edges wander, never ruler-straight (`EDGE_ROUGH`), the cracks run at odd angles and **bend** here and there — shard and joint bend together, as real broken ceramic (`CUT_WOBBLE`; never near the tile's outline, so it still fits the mural) — and no shard is tiny (`SHARD_MIN`); here and there the glaze **flaked off** in shell-shaped bites and the fired clay shows — terracotta or pale (`CHIP_DEPTH`, `BODY_*` colours).
- **Marbled glaze** (*jaspeado*) on some plain tiles, with fine light veins (`MARBLE_SHARE`), and **crackled glaze** (craquelure, a fine net of cracks) on others (`CRACKLE_SHARE`).
- **Coloured glass** for very rare words: deep, glowing where the light comes out, the mortar showing through its thin edges (`GLASS_BOTTLES` adds round bottle bottoms; off).
- **Moulded relief tiles** (*rajoles de relleu*), like the green ones with leaves and berries on the benches: deep glaze in the hollows, thin on the tops where the clay shows through (`RELIEF_TILE_SHARE`, more among the shards from other tiles, i.e. very Catalan words; glazes `RELIEF_GLAZES`).
- **The ribbon** on top of each tile is a round glazed moulding, as the capping of the benches.
- **Gold lustre** shards reflect like metal.
- **The mortar** is warm lime with sand grains and stains (`GROUT_COLOR`), the joints are uneven — every edge of a shard at its own distance from its neighbour (`GROUT_WIDTH`, `GROUT_IRREGULAR`) — darker right against the shards because they stand proud (`AO_STRENGTH`, `AO_RADIUS`), with a short contact shadow away from the light (`CONTACT_SHADOW`, `SHADOW_LEN`).
- Motifs are sampled with a slight wobble, as if painted by hand (`PAINT_WOBBLE`).

When a tile is set in the mural it is resampled from its baked image straight onto the mural's own pixel grid and drawn 1:1 (`muralStamp()`), so it stays as sharp as when it assembled (letting the graphics card shrink it on the fly blurred it). For full sharpness in the venue use `RENDER_SCALE = 1.0` (native resolution: at 0.5 the venue enlarges the image 2×, which softens the mural; the big tile assembling on WALL 3 hides it). A tile takes ~0.1–0.3 s to bake (when the word arrives); the tiles restored into the mural at start and the poem tiles are baked with less detail (`BAKE_DETAIL_MURAL`, `BAKE_DETAIL_POEM`). `CERAMIC_BAKE = false` brings back the old flat look. All in the "Ceramic look" section of `Config.pde`; colours in `Colors.pde`.

### Phenomenon → motif and breakage

| Value | Phenomenon | Painted motif | Breakage |
|---|---|---|---|
| 1 | Static | Modernista ornamental tiles: scalloped arches, corner fans, interlaced strapwork, small sprigs | clean |
| 2 | Soft dispersion | Plain shards in many shades of one colour | very chipped |
| 3 | Spiral deformation | Moorish rosettes (eight-point star ringed by hexagonal petals) | medium |
| 4 | Noisy sub-clusters | Six different decorated tiles, broken and mixed (stars, chains, stripes, small crosses, sunburst, a heraldic tile: golden stars on a cobalt diamond) | medium |
| 5 | High-frequency vibration | Valencian eight-point stars with small crosses | the most chipped |
| 6 | Directional drift | Bold near-black and yellow geometry: chevrons, diamonds, triangles, or the black / white / orange checker of the benches | crooked |
| 7 | Place | *Lacería*: a lattice of interlaced eight-point stars, light bands outlined in dark — pure geometry, no flowers | clean |

The tile is broken like real ceramic: straight cracks cut the biggest pieces again and again, some areas are crushed into small chips, and some pieces lose a corner — so shards have 3 to 7 sides and irregular angles. Each shard is set back slightly off, so the motif is cut by the cracks. Every tile on the top of a band has a ribbon of dark pieces along its top edge; each band of the mural has its own ribbon tone, which draws the wavy lines of the mural.

### Word class → how the shards come in

All shards come from far behind WALL 3 (`ASSEMBLE_DEPTH`), scattered wide (`ASSEMBLE_SPREAD`), dark and out of focus, and become sharp and lit as they reach their place — small ones first, the big ones at the back last. The word class sets their path:

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

When it leaves WALL 3 **the tile breaks**: it shakes for an instant, then it bursts into big **chunks** of neighbouring shards (about `CHUNK_SHARDS` each) thrown out all at once (`BURST`); each chunk travels on its own and they all close up again in the slot on WALL 1. In the air a chunk has **depth**: it comes off the wall — a soft shadow falls on the wall behind it (`CHUNK_SHADOW`, `CHUNK_SHADOW_DIST`), it grows a little (`CHUNK_GROW`), tilts in perspective (`CHUNK_TILT`, never showing its back) and shows its thickness of fired clay (`CHUNK_THICK`). The emotion decides how the cloud splits:

| Emotion | Routes |
|---|---|
| Love, Sadness | keeps together: WALL 2, WALL 4 or the floor |
| Joy, Surprise | splits in two: usually WALL 2 + WALL 4, sometimes one wall + the floor |
| Anger, Fear, Disgust | splits in three: WALL 2 + WALL 4 + the floor |

The left part of the tile goes round by WALL 2, the right part by WALL 4, the lowest part across the floor (turning round to arrive upright).

### 2D or 3D travel (`TRAVEL_3D`, Ctrl+D)

- **2D (`false`):** the pieces travel on the walls and the floor, with their own relief — they tilt in perspective, show their fired-clay thickness, cast a soft shadow on the wall and move in different depth planes (`CHUNK_TILT`, `CHUNK_THICK`, `CHUNK_SHADOW`, `CHUNK_DEPTH`). Looks right from anywhere in the room.
- **3D (default, `true`):** the pieces leave WALL 3 into the room and fly through the air, each at its own depth (on the WALL 2 side, the WALL 4 side or low over the floor), and land on WALL 1. Each surface is rendered from the audience's point of view — centre of the room, eye height `VIEWER_HEIGHT` — with an off-axis projection (a virtual camera rig, `viewerCamera()` in `Room.pde`), so the pieces line up across walls and floor. The illusion is perfect from that point and more distorted further away. Pieces stay below eye level: anything higher would be projected towards the ceiling, where nothing is shown.

### Art direction (`ART_*` in `Config.pde`, `Ctrl+B` before / after)
"Walls keep the words as matter; the floor keeps them as language." Every effect has its own switch, and `Ctrl+B` turns them all off and on to compare (materials apply to tiles made from then on):
- **Materials:** each tile is about two thirds clean glaze in shades of its colour, the painted pattern surviving in patches (`ART_PLAIN_MIX`, `PLAIN_SHARE`); calmer, harmonised glazes over the whole mural (`ART_HARMONY`, `HARMONY_SAT`); joints a little darker (`AO_STRENGTH`).
- **The word:** it first appears big and readable on the main wall and the tile forms behind it as it fades (`ART_WORD_REVEAL`, `WORD_REVEAL_SIZE`); the tile barely trembles and its cracks open slowly before the chunks leave as a cohesive stream (`BURST`, `SCATTER`).
- **Light:** the stream lights the walls it passes, softly and warm (`ART_TRAVEL_GLOW`, `TRAVEL_GLOW`); when the tile settles, a warm local glow and a wave of light running out through the glazes and ribbons of the mural (`ART_IMPACT_WAVE`, `IMPACT_WAVE`, `IMPACT_FRAMES`). All light is warm (`WARM_LIGHT_COLOR`), never white.
- **The floor:** words drift in a slow current round the room, each in its lane, reading along their way, the centre kept clear for the verse (`ART_FLOOR_FLOW`, `FLOW_LANE_*`); fewer at once (`MAX_FLOOR_WORDS` 180); a visitor's word arrives golden and a little bigger and joins the poem's colour over ~25 s (`ART_TYPED_GLOW`, `TYPED_NEW_COLOR`).

**The mural under a live light (`Mural.pde`, shader `data/mural.glsl`, `ART_MURAL_LIGHT`).** Every tile also bakes a **relief map** — the normal of each shard (its tilt, its rolled edges, the moulded reliefs) and how glossy it is — stamped into a layer next to the mural's colour. The mural is then drawn through a GLSL shader lit by moving lights, so the glaze shines and the edges catch the light as they move, while the sunk mortar stays matte:
- a calm, broad light wandering slowly along the mural (WALL 4 → 1 → 2 and back; `AMBIENT_LIGHT`, `AMBIENT_PERIOD`, `AMBIENT_LIGHT_COLOR`);
- the warm light the travelling stream carries over the walls it passes (`TRAVEL_LIGHT`);
- when a tile settles, a local warm light (`IMPACT_LIGHT`) and a **wave of light running along the bands of the mural, across the corners onto the next walls**, decaying slowly (`IMPACT_WAVE`, `WAVE_REACH`, `WAVE_WIDTH`, `WAVE_FRAMES`);
- `MURAL_RELIEF`, `MURAL_SHININESS`: how much the relief shows, how sharp the reflections are.
While a word travels the room steps back: the poem and the calm light dim (`CALM_DIM`). The chunks travel in different planes (`CHUNK_DEPTH`: nearer ones bigger, further ones smaller and dimmer) and the stream turns on itself as one body (`STREAM_SWIRL`). On the floor, nouns, verbs and adjectives are bigger and little words smaller and softer, each with a hint of its tile's colour (`ART_FLOOR_TYPE`, `FLOOR_TINT`); a visitor's word on the floor pulses when its tile settles in the mural.

### The word, and the floor as a page (v4)
- **The word becomes the tile** (`Reveal.pde`, `ART_WORD_REVEAL`). On ENTER the word appears very big and centred where its tile will form on the main wall (`WORD_REVEAL_SIZE`, never wider than `WORD_MAX_WIDTH`), fading in over `WORD_IN_FRAMES`; it stays alone `WORD_SHOW_FRAMES` (1.5 s, or longer while the model answers — the word itself is the wait); then word and tile **crossfade in the same place** over `WORD_XFADE_FRAMES` (word 100 → 0 %, tile 0 → 100 %, eased); once the tile is whole it breaks and travels as before. A rejected word just fades away.
- **The text box** is minimal: centred, the invitation or what is being typed, a breathing cursor; messages small underneath. No "last word" line and no ">" any more; the box sits higher (`UI_Y` 0.66), clear of the big word.
- **The floor as a page** (`FloorPoem.pde`, `ART_FLOOR_POEM`). No more drifting, orbiting words: the poem is **written directly on the floor**, verse by verse (two or three lines, in order), word by word with slow fades (`VERSE_STAGGER`, `VERSE_FADE_IN`), stays (`VERSE_STAY`), fades (`VERSE_FADE_OUT`) while the next verse builds in another place (`LANES`); at most `VERSE_MAX` at once, all reading the same way, lots of black. The visitors' words become **small footprints** along the two ends of the floor, never over the poem: they arrive golden (`FOOTPRINT_GOLD_FRAMES`, and again when their tile settles), then turn discreet (`FOOTPRINT_COLOR`, `FOOTPRINT_ALPHA`); at most `FOOTPRINT_MAX`, the oldest fades. With it on, poem words no longer come out of the walls. Without a floor (IASLab) the old behaviour stays.

### The floor: the echo of the trencadís (`FloorEcho.pde`, shader `data/floor_echo.glsl`; `FLOOR_ECHO = 1`)
The floor is black glaze reflecting the mural: every point reflects the wall in front of it, soft and slow, strongest at the foot of the walls and fading towards the centre (`ECHO_A_STRENGTH`, `ECHO_REACH`, `ECHO_STRETCH`, `ECHO_BLUR`, `ECHO_WARP`). It is mostly atmosphere, and only now and then language:
- **A verse is revealed** (one after another: each appears, stays, fades, and `ECHO_VERSE_GAP` — 5 s — later the next; a verse waits while a word is travelling): in a wide, edgeless area the reflection calms (its slow movement settles) and dims (`ECHO_CALM_*`), as if showing a layer underneath; the line of Espriu is latent there — first a faint typographic haze (`ECHO_VERSE_FOG`), then it gathers into clear, quiet letters (`ECHO_VERSE_ALPHA`), stays, and loosens back into haze and the floor (`ECHO_VERSE_IN`, `_STAY`, `_OUT`). In two lines, small (`ECHO_VERSE_EM`), each verse somewhere else on the floor away from the drifting words, with a slight tilt of its own (`ECHO_VERSE_TILT`); no movement, no scaling, warm off-white, one at a time, the lines in order.
- **A visitor's word is inscribed**: when its tile settles, a wave in the tile's colour leaves the foot of its wall; then a little warm light gathers a little into the room (`ECHO_WORD_GLOW`, `ECHO_WORD_LEAD`) and the word is written there in light, letter by letter (`ECHO_WORD_WRITE`), each letter appearing bright and settling to amber; readable for a few seconds (`ECHO_WORD_STAY`), then it fades (`ECHO_WORD_OUT`); then it settles into a discreet amber and stays on the floor, drifting slowly in long gentle curves and turning subtly (`ECHO_WORD_TURN`), stirring the glaze under it — slow rings, the reflection brightening beneath it (`ECHO_WORD_RIPPLE`) — keeping its distance from the others and from the verse's place (`ECHO_WORDS_DRIFT`, `ECHO_DRIFT_SPEED`, `ECHO_DRIFT_ALPHA`, `ECHO_DRIFT_ROOM`); The words are **set into the glaze**, not laid on top (`ECHO_WORDS_IN_GLAZE`): drawn into their own layer and placed by the floor shader, they are lit by the reflection around them (brighter over the mural's light, faint in the dark), warped with the slow movement of the surface, with soft edges that breathe slowly, and as they age they sink — softer and fainter (`ECHO_GLAZE_*`). **The floor keeps a register**: the last `ECHO_WORDS_KEEP` (20) words typed stay on the floor for `ECHO_WORD_LIFE` (15 min), more and more transparent as they age, then they are gone; when a 21st arrives the oldest fades. The time each word was typed is saved with the mural, so after a restart the recent ones come back to the floor as old as they really are.
`ECHO_REVEAL_STYLE = false` brings back the openings. No orbiting, drifting or accumulated words. `FLOOR_ECHO = 0` brings back the v4 floor; `Ctrl+F` cycles v4 / A / B / C (B fragmented reflections, C almost black — the other prototypes).

### Moments (`Moments.pde`)
What makes people go "ooh" (settings in "The journey and the moments", `Config.pde`):
- **Your tile, found again.** When a tile settles in the mural it lights up for a few seconds (`LAND_GLOW_FRAMES`, `MARK_GLOW`). Typing a word that is already in the mural makes its older tiles pulse ("la meva encara hi és", `AGAIN_GLOW_FRAMES`).
- **Special words.** A word with raresa or culturalitat ≥ `SPECIAL_MIN` (6) is announced on WALL 3 — "✦ Paraula rara ✦", "✦ Molt catalana ✦", "✦ Rara i molt catalana ✦" (`MSG_RARE*`) — assembles and stays slower (`SPECIAL_SLOW`) and a golden reflection sweeps over it (`SPECIAL_SHEEN`).
- **Light on the mural.** Now and then a soft diagonal band of light travels over WALL 4 → WALL 1 → WALL 2 and catches the glazes, the gold and the glass, not the mortar (every tile also bakes a gloss image for this; `MURAL_SHEEN`, `SWEEP_FRAMES`, `SWEEP_PAUSE`).
- **The mural is full.** It glows and sweeps fast, a chord plays, and a new layer begins over the oldest tiles (`CELEBRATE_FRAMES`).
- **A verse forms.** Every `VERSE_EVERY` (4 min) the first two lines of the poem form in the middle of the floor, word by word, read facing the main wall, stay `VERSE_HOLD` and fade (no floor: along the bottom of the mural, over a dark band).
- **The text box** has no line any more; when empty it invites "Escriu una paraula en català…" (`MSG_INVITE`), and the cursor breathes instead of blinking.

### The mural (WALL 1)

- WALL 1 is divided once (`MOSAIC_SEED`) into wavy bands (`MOSAIC_ROWS`) of straight-edged cells; the waves are faceted. With the defaults there are 69 cells. They fill from the centre outwards; when the whole mural is full new tiles cover the oldest.
- **Neighbours never look alike.** Every tile gets a variant (0–3: another ground, another shade of its colour, another version of its motif), chosen unlike the nearby tiles that share its motif or its colour (`pickStyle()`, saved with the tile).
- **The cells adapt to the tiles** (`allocate()` in `Mosaic.pde`): a small tile (common word) takes half a cell — split left / right with a slanted cut if the cell is wide (`SPLIT_WIDE`), top / bottom if not — and the next small tile fills the other half; a big tile (rare word) joins a cell with its free neighbour in the same band. So the mural keeps its wavy bands but its pieces have many sizes. Where each tile went is saved with it, so the mural comes back the same after a restart. The mural always closes up: a small tile first fills the free half of a split cell (at most one half is open at a time); a rare word that finds no free neighbour takes one cell; when only half cells are left, normal words take them; it only starts again when every cell is full. On the side walls every tile still touches one already placed. (Checked with 2000 random words.)
- The dark ribbons along the top of the tiles draw the coloured wavy lines that divide the mural into horizontal bands. A lower half (the bottom part of a split cell) has no ribbon — the upper half above it has it, so the line stays whole. `RIBBON_SHARE` < 1 leaves some tiles without it (the lines then come in pieces).
- When WALL 1 is full the mural grows on both side walls at once, from the back corner towards the front; every new tile touches one already placed (`MOSAIC_SIDES`). The poem keeps to the part of the side walls the mural hasn't reached.
- The grout (thin grey cement) only appears when a tile lands: it seeps in under the shards, dark and wet, and dries to its final colour.
- The mural is saved in `data/mosaic.json` and restored on start. `Ctrl+N` clears it.

### The border (`Cenefa.pde`, `CENEFA`)

A row of trencadís runs round the top of the room, over the four walls (WALL 4 → 1 → 2 → 3), like the glazed capping of the Park Güell benches. It frames the room and makes the mural read as one piece. On / off: `CENEFA` in `Config.pde`.

- **Made of the poem** (`CENEFA_POEM`): every cell is a word of Espriu's poem, in order round the room (it starts again when the words run out), each with the colour, motif and cuts of its own analysis in `data/poem_words.json`. So the walls hold the visitors' words and the poem crowns them. With `CENEFA_POEM = false` the cells take the glazes of `CENEFA_COLORS` (`Colors.pde`) in turn, and `CENEFA_PAINTED_EVERY` > 0 makes every n-th one painted.
- **Irregular, like the mural**: its lower edge waves like the mural's bands (`CENEFA_WAVE`, 0 = a straight line), in straight facets; the joins run at odd angles (`CENEFA_SLANT`). The wave closes on itself round the room, so it carries on from wall to wall at every corner. A glazed capping runs along its top (`CENEFA_RIBBON`, a tone of `RIBBON_COLORS`).
- Baked once at start (under a second) into a layer per wall and drawn under the same live light as the mural, so the wave of a tile settling also runs along it.
- The mural sits just below it, following its wave, with a thin dark joint (`CENEFA_GAP`): its bands are squeezed into the rest of the wall, the cells keep their widths, so a saved mural comes back in the same slots. `CENEFA = false` gives the whole wall back to the mural.
- Other settings: `CENEFA_H` (height, × the wall height), `CENEFA_CELL_MIN` / `MAX`, `CENEFA_SHARD`.

### Floating shards (`Motes.pde`, `MOTES`)

Little shards of tile float very faintly in the empty parts of the walls: real baked shards (tiles made from words of the poem), drifting slowly round the room, turning and now and then tumbling edge-on. Each has its own depth: far ones are small, darker (`MOTES_FAR_DIM`), slower and fainter; near ones bigger and clearer — a quiet parallax. They pass behind the mural and the border, so they only show where the wall is still empty; they keep clear of the centre of the main wall (the word, the tile forming) and fade while a word is on its way. On / off: `MOTES`; also `MOTES_COUNT`, `MOTES_SIZE`, `MOTES_ALPHA`, `MOTES_SPEED`.

---

## Project structure

```
language_viz/
├── language_viz.pde      — Main sketch: setup, draw, keyboard
├── Config.pde            — All settings (room, output, mosaic, timing, LLM, sound…)
├── Colors.pde            — Every colour (background, text, floor words, emotion → tile colour, ceramic, grout, ribbons) and the typeface
├── Reveal.pde            — The typed word, big, crossfading into its tile
├── FloorPoem.pde         — The poem written on the floor verse by verse; visitors' words as footprints
├── FloorEcho.pde         — The floor reflecting the mural; verses and visitors' words from openings in the reflection
├── Cenefa.pde            — The trencadís border round the top of the room
├── Motes.pde             — Little shards floating faintly in the empty parts of the walls
├── Mural.pde             — The mural under a live light (shader data/mural.glsl): moving lights on the relief map, waves along the bands
├── Moments.pde           — Tiles lighting up with their word, special words, light sweeping the mural, full-mural celebration, the verse on the floor
├── RoomView.pde          — Ctrl+I: first-person view inside the room, with simulated projectors (Ctrl+J)
├── Room.pde              — Walls + floor, media matrix, cameras (flat, main wall, 3D viewer), preview, calibration
├── Trencadis.pde         — A tile: palette, painted motifs, breaking into shards, drawing, assembly
├── Ceramic.pde           — Bakes each tile as real glazed ceramic in lime mortar (light, glaze, chips, marble, relief)
├── Mosaic.pde            — WALL 1 mural (slots, saving) and each tile's journey (assemble → travel → set)
├── Output.pde            — Output images for PIXERA: media matrix or groups of surfaces; windows / Syphon / Spout
├── WordsSystem.pde       — Poem words floating as small tiles
├── ClaudeSketch.pde      — Text input on the main wall, API state
├── ai_agent.pde          — Model / Anthropic API call (background thread)
├── CatalanLLM.pde        — One word in Catalan: local filter, Viquidiccionari, model, answer schema, cache, word frequency, analysis, language test
├── LocalLLM.pde          — The local model: starts / stops llama-server, requests to Salamandra
├── utils.pde             — Request builder, response parsing, test-mode / no-API parameters
├── JSONLoader.pde        — Reads input.json (and watches it for changes)
├── SoundEngine.pde       — MIDI chord generation entry point
├── MidiController.pde    — Low-level MIDI output via themidibus
├── ChordBuilder.pde      — Maps parameters to MIDI notes
├── JSONParser.pde        — Helper to trigger sound from a raw JSON string (testing)
├── miditest.pde          — MIDI test sketch (commented out)
├── data/
│   ├── input.json        — Current word and its parameters
│   ├── poem_words.json   — The poem (Salvador Espriu), word by word with parameters
│   ├── catalan_freq.tsv  — Catalan word frequencies (wordfreq) → raresa
│   ├── lexicon_cache.json — Every word already analysed (in git)
│   ├── ollama_key.txt    — Your Ollama API key (NOT in git)
│   ├── language_test.txt — Last Ctrl+K result (not in git)
│   ├── llama_server.log  — Log of the local model server (not in git)
│   └── mosaic.json       — The mural (created automatically, not in git)
├── models/               — The local model, salamandra-7b-instruct-2606.i1-Q4_K_M.gguf (downloaded by the setup scripts, not in git)
├── prompts/
│   ├── catala_art_system_prompt.md — System prompt (Catalan) sent to the model
│   └── haiku_art_system_prompt.md — Old English prompt
└── Reaper/
    └── miditest.rpp      — Reaper project for the sound
language_viz_original/    — Earlier version of the sketch (particles, single screen)
tools/make_catalan_freq.py — Rebuilds data/catalan_freq.tsv from wordfreq
tools/make_poem_words.py  — Analyses the poem's words → data/poem_words.json
setup_mac.command, setup_windows.bat — Install llama.cpp + download the local model (Salamandra)
```

---

## Setup

### Requirements
- [Processing 4](https://processing.org/download) and the library **themidibus** (Processing's Library Manager).
- The local model: [llama.cpp](https://github.com/ggml-org/llama.cpp) + Salamandra 7B Instruct 2606 (≈ 4.9 GB), installed by `setup_mac.command` / `setup_windows.bat`. A computer with ≥ 16 GB of memory.
- Internet for the Viquidiccionari (and, optionally, Ollama Cloud as a fallback). Without it the installation keeps working, with less accurate analysis (see below).
- Optional: an **Ollama** account and API key (free plan) for the cloud fallback; Reaper or any MIDI app (for the sound), Syphon / Spout (to send the image out).

### Quick start (local model, default)
1. Once per computer, double-click `setup_mac.command` (macOS, uses Homebrew) or `setup_windows.bat` (Windows, uses winget): it installs llama.cpp and downloads the model into `language_viz/models/` (not in git: far bigger than GitHub allows).
2. Open `language_viz/language_viz.pde` in Processing and run. The sketch starts the model server by itself (`LocalLLM.pde`); the console says `Local model: starting llama-server…` and then `Local model ready`. Reading the instructions the first time takes ~20 s (longer on a laptop in Low Power Mode); words typed meanwhile wait.
3. Type one word in Catalan and press Enter. The console shows the analysis and `[mode: local]`. Closing the sketch stops the server.

### Cloud fallback (optional)
1. Create a free account on [ollama.com](https://ollama.com) → *Settings → API keys* (https://ollama.com/settings/keys) → *Create API key*.
2. Paste the key in `language_viz/data/ollama_key.txt`, on the empty line under the comments (`OLLAMA_API_KEY = "…"` also works). The file is ignored by git: **never commit a key, and never paste it in a chat or a README**. Each computer needs its own copy of this file.

### The local model: Salamandra
[Salamandra 7B Instruct 2606](https://huggingface.co/BSC-LT/salamandra-7b-instruct-2606) (BSC, Apache 2.0, June 2026) was trained on 35 European languages with special care for Catalan, Spanish, Basque and Galician. The GGUF file (`i1-Q4_K_M`, from [mradermacher](https://huggingface.co/mradermacher/salamandra-7b-instruct-2606-i1-GGUF)) runs on llama.cpp's `llama-server`, not Ollama: BSC advises against Ollama for it. How the sketch talks to it (`LocalLLM.pde`):
- The server listens only on this computer (`127.0.0.1:LLAMA_PORT`, 8091), with an 8k context and the whole model on the GPU. Its log goes to `data/llama_server.log`. If one is already running (e.g. left behind by a crash), it is reused.
- Salamandra's template has no system role: the instructions open the first user message. The examples at the end of the prompt (`## Exemples`) are sent as real turns (word → JSON); written inside the instructions, the 7B model copied the first one for most words.
- The answer is forced to a JSON schema with two shapes: a rejected word only gives `es_catala: false` and `motiu`; an accepted one gives every parameter, in an order that leaves the emotion and its colour last (with the emotion first, the model copied the numbers of the example with the same emotion).
- **Tested** (Oct 2026, M2 16 GB, `Ctrl+K` list): 33 / 34 words accepted / rejected as expected (*hola* is rejected); every foreign, misspelt or non-existent word is caught. The 1–7 scales are noisier than with `gemma4:31b` (e.g. *tristesa* culturalitat 6).
- **Speed** (M2 16 GB, plugged in): llama.cpp alone writes ≈ 19 tokens / s, but while the sketch renders the room it shares the GPU and drops to ≈ 6. So, in the installation, an accepted word (~100 tokens) takes 15–25 s, a rejected one ≈ 4 s, and reading the instructions at start ≈ 50 s. Low Power Mode is about 3× slower still. For comparison, Ollama Cloud answers in ≈ 1 s. Cached words are instant.
- If the sketch is killed outright (crash, force quit), the server keeps running; the next run recognises it, reuses it (instantly, with the instructions still read) and stops it on exit.

### Which model (`Config.pde`)
```java
final String LLM_PROVIDER       = "ollama";      // or "claude"
final String LLM_MODE           = "auto";        // "local" | "cloud" | "auto"
final String LOCAL_ENGINE       = "llamacpp";    // Salamandra on llama-server | "ollama"
final String OLLAMA_MODEL_CLOUD = "gemma4:31b";
```
- **Switch while running with `Ctrl+O`** (auto → cloud → local); the top of the preview window shows the mode and whether Salamandra is starting / ready / failed and the cloud has a key. In cloud mode the local server keeps running, so switching back is instant; switching to local / auto starts it if it isn't running (also a retry after a failure).
- **auto (default):** the local model; if it doesn't answer, the cloud.
- **local:** only the local model: Salamandra on llama-server (`LOCAL_ENGINE = "llamacpp"`, settings `LLAMA_*`) or `OLLAMA_MODEL_LOCAL` on a local Ollama (`"ollama"`, `http://localhost:11434`; gemma3:4b analysed Catalan poorly).
- **cloud:** [Ollama Cloud](https://docs.ollama.com/cloud), `https://ollama.com/api/chat`, with the key from `data/ollama_key.txt`. Of the models in the free plan, `gemma4:31b` gave the best analyses (`gpt-oss:120b` and `nemotron` were worse; the rest need a paid plan). The free plan has usage limits that reset every few hours / weekly; the cache keeps the cost low. Cloud models: `curl https://ollama.com/api/tags`. Note: Ollama Cloud ignores the JSON schema (`format`) for `gemma4:31b` — it answers in the prompt's format, inside a ```json fence, which the sketch strips.
- If no model answers (no network, no key, limit reached), a word that passed the local filter gets parameters derived from the word itself, without checking the language — the installation never stops. The console says `[mode: fallback]`.
- **Claude:** `LLM_PROVIDER = "claude"` and the key in `API_KEY` (**never commit it**).

---

## Analysing a word

What happens when a visitor presses Enter (`submitWord()` in `CatalanLLM.pde`):

```
1. Local filter      one word, Catalan letters only, ≤ 30 letters          instant, offline
   Accents           a missing / wrong accent is corrected: cafe → cafè     instant, offline
2. Cache             already analysed? → use it, no network                 data/lexicon_cache.json
3. Viquidiccionari   look the word up, take its definition                  ca.wiktionary.org
4. Model             word + definition → is it Catalan? + all parameters    Salamandra (local), else Ollama Cloud
5. wordfreq          raresa = the word's real frequency in Catalan texts     data/catalan_freq.tsv
6. → tile, sound, mural    (or a short message in Catalan if it's rejected)
```

### 1. Only one word in Catalan
1. **Local filter, instant.** One word, at most `MAX_WORD_LENGTH` (30) letters, only the Catalan alphabet: a–z, à è é í ï ò ó ú ü ç, the punt volat of l·l (`l.l` is accepted and turned into `l·l`) and an inner hyphen (`pell-roja`). Numbers, symbols, emoji, apostrophes (`l'aigua` = two words) and foreign letters (ñ, á…) are rejected. The text box doesn't even let you type spaces or those characters.
2. **The model**, helped by the Viquidiccionari, in the same call as the parameters (`es_catala` / `motiu`): Catalan dictionary words (also those shared with other languages: *casa*, *mar*), inflected forms and Catalan place / proper names are accepted; other languages (*cuchara*, *hello*), non-standard Castilianisms (*bueno*, *vale*) and non-existent or misspelt words (*enyprança*) are rejected.

A rejected word makes no tile, no input.json and no sound: a short message in Catalan appears on the main wall for a few seconds (`MSG_*` in `Config.pde`).

**Missing or wrong accents are corrected** (`fixAccents()`, `USE_ACCENT_FIX`). Every word of the frequency table (`data/catalan_freq.tsv`) is indexed without its accents (and ç → c); if what the visitor typed is much rarer than a form of it with other accents, that form is used and the wall says *Volies dir «cafè»?* (`MSG_DID_YOU_MEAN`) while the tile of the corrected word assembles. Offline and instant. Rules, tested on 57 words:
- Without accents: corrected when the accented form is at least `ACCENT_FIX_GAP` (1.4 zipf, ×25) more common and itself common (`ACCENT_FIX_MIN`): *cafe* → cafè, *tambe* → també, *musica* → música, *perque* → perquè, *pero* → però, *avio* → avió, *esperanca* → esperança, *canco* → cançó, *pais* → país. A capital stays (*Musica* → Música).
- Words that are also correct without the accent stay as typed: *mes*, *te*, *mon*, *ma*, *sol*, *dona*, *pel*, *si*, *os*.
- With an accent: a common word is never changed — the diacritic accents *pèl*, *fóra*, *vós*, *sòl*, *dóna*, *té*, *ós* are words (`ACCENT_WRONG_MAX`, zipf 3); a rare one with a smaller gap (`ACCENT_FIX_GAP_WRONG`): *mès* → més, *pà* → pa, *àrbre* → arbre, *cafés* → cafès, *Barcelóna* → Barcelona.
- Not corrected: *café* (frequent in Catalan web text, as common as real accented words — the model rejects it as Spanish), *angel*, *adeu*, *bebe* (the accented form isn't common enough to be sure). Misspelt letters (*escudela*) aren't corrected: the model rejects them.

**Accents.** Some windows don't compose dead accent keys (the key arrives without a character): the sketch then recognises the accent key itself — ` and ´ (Shift: ¨) where they are on Spanish / Catalan keyboards — and puts the accent on the next vowel. If an accent key still does nothing, set `DEBUG_KEYS = true`: the console prints what each key sends. Typed the other way round also works, accent first and then the vowel: `` ` `` + a/e/o → à è ò, `´` or `'` + vowel → é í ó ú, `¨` or `"` + i/u → ï ü.

### 2. Cache
Every answer (also rejections) is stored in `data/lexicon_cache.json` (lower-case word → JSON, with the definition). A word already there doesn't call the network again: it's instant, free and always gives the same analysis. The file **is kept in git**, so every computer (and the venue) gives the same tile for the same word, and a wrong decision of the model can be fixed by hand there (or delete the entry to ask again). Turn it off with `USE_LEXICON_CACHE = false`. Changing the model or the prompt doesn't change words already cached: empty the file (`{}`) to analyse them again.

### 3. Viquidiccionari (definitions)
The language models don't know many Catalan words: asked for definitions, gemma3:4b said *pessigolles* was a town, gemma4:31b that it is "a person who annoys others", *esbarzer* "having fun" and *bassal* "a pigeon". So before asking the model, the sketch looks the word up in the Catalan Wiktionary — free, open, no account (`lookupDefinition()`, `USE_DICTIONARY`, `DICT_URL`):
- It reads the word's page through the public API (`ca.wiktionary.org/w/api.php?action=parse…`), takes the **Catalan** section and keeps up to 3 definitions, without wiki markup. It also tries lower case and a capital initial (*Montserrat*).
- **Inflected forms** (*castellers*, *cantàvem*, *bonica*) only say "plural of…" / "form of…": the sketch follows the link and sends the base word's definition — "(forma de casteller) Persona que fa castells humans".
- Four outcomes: a definition → sent with the word · the page exists but not in Catalan (*cuchara*) → the model is told · no page (*enyprança*) → the model is told · no answer within ~6 s → the model decides alone.
- The dictionary never rejects a word by itself (many valid forms have no page); it only informs the model.

The model receives the instructions (`prompts/catala_art_system_prompt.md`: acceptance rules, emotion → colour table, the 1–7 scales with examples, worked examples) and a message like:
```
pessigolles
Definició del Viquidiccionari: Sensació que s'experimenta en algunes parts del cos
quan són estimulades lleugerament pel tacte i que sol provocar involuntàriament la rialla.
```
It answers with a JSON object; the sketch checks every value is in range (`cleanParams()`), adds the definition and stores it in the cache.

### 4. Two new parameters
- **`culturalitat`** 1–7: how tied **what the word names** is to Catalan culture — customs, festivals, food, objects, places, character. Judged by the model, with examples for every level in the prompt: 1 *taula*, *tristesa* · 2 *mar*, *pa* · 3 *mercat*, *mongeta* · 4 *platja*, *festa major* · 5 *espardenya*, *botifarra* · 6 *porró*, *calçot*, *gegant* · 7 *castellers*, *sardana*, *seny*, *rauxa*, *Montserrat*. A very Catalan *word* for a universal thing is not cultural (*enyorança*, *pessigolles* → 1–2). There is no objective measure for this; clear cases come out right, middle values (3–5) vary more.
- **`raresa`** 1–7: how rare the word is — **measured, not guessed**. Its frequency in real Catalan texts (Wikipedia, web, subtitles, news…) from [wordfreq](https://github.com/rspeer/wordfreq) (data CC BY-SA 4.0), exported once to `data/catalan_freq.tsv` (185 000 words, 2.4 MB) by `tools/make_catalan_freq.py`. It replaces the model's guess, also for cached words. Zipf frequency → raresa with `RARESA_ZIPF`:

| zipf ≥ | 5 | 4.5 | 4 | 3.5 | 3 | 2.5 | below |
|---|---|---|---|---|---|---|---|
| raresa | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| e.g. | *casa* 5.8 | *finestra* 4.6 | *castellers* 4.1 | *sardana* 3.8 | *pessigolles* 3.1 | *calçot* 2.9 | *xiuxiuejar* 2.2 |

  Inflected forms take their base word's frequency when it's higher (*cantàvem* = *cantar*). Words not in the table: 7. Without the file (`USE_WORD_FREQ = false`) the model's guess is used. To rebuild the table: `python3 -m venv venv && venv/bin/pip install wordfreq && venv/bin/python tools/make_catalan_freq.py`.

How they change the tile: see [Rich words are rewarded](#the-parameters--visuals).

### 5. Seeing the analysis
Every word prints its analysis in the console, one line per category with what it changes:
```
"pessigolles"   mode cloud
emoció         7  Alegria      → color, so
classe         1  nom          → entrada al mur
fenomen        5  percepció    → dibuix del rajol
abstracció     5               → mida dels bocins
orgànic        7               → irregularitat dels talls
culturalitat   4               → quants bocins, d'altres rajols
raresa         5  freq 3,12    → mida del rajol, daurats
significat     Sensació que s'experimenta en algunes parts del…
```
`mode` says who answered: `cloud`, `local`, `cache`, `fallback` (no model) or `test` (random). In test mode (`Ctrl+E`) the same panel is shown on WALL 3.

**Language on screen:** everything the public sees in the projection is in Catalan (the messages for rejected or corrected words, the analysis panel); technical text for the team — the preview window, the calibration pattern, "TEST MODE", the console — stays in English. While the model thinks, seven shards of a freshly broken tile — the same glazed, relief shards as the mural — orbit slowly where the tile will appear, half transparent (`THINK_ALPHA`), turning over on themselves as if the tile were being put together (`drawThinking()` in `ClaudeSketch.pde`); the tile still on the wall leaves at once to make room. The tile on WALL 3 is never drawn over the text box: tall cells are shown a little smaller (`HOLD_Y` 0.37), and never over the border at the top.

The bottom of the preview window always shows, large, what is being typed, "thinking…" while the model answers, the rejection message or the last word (`PREVIEW_INPUT`; never in the output).

### Tests
- **`Ctrl+E` test mode:** each word gets its real analysis (cache or model), shown on WALL 3. Test tiles are not saved in the mural; leaving test mode brings back the real mural. With `TEST_RANDOM = true` the model is skipped and parameters are random.
- **`Ctrl+K` language test:** runs a list of words that should be accepted / rejected through both filters and the model, and prints a table with the mode that answered (also saved in `data/language_test.txt`).

---

## Colours and typeface (`Colors.pde`)

Every colour is in its own file, written as `"#RRGGBB"` (any colour picker gives them), with what each one paints:
- **The room:** `BACKGROUND_COLOR` of the walls and floor.
- **Text box on WALL 3:** the word being typed, the `>`, the line, the last word, the messages, "TEST MODE", the band behind the box.
- **Words on the floor:** the poem's, the visitors' (separately) and the dark halo around them.
- **Tile colour from the emotion:** `EMOTION_COLORS` (the same table the model is given). `EMOTION_COLOR_SOURCE = "model"` uses the shade the model chose; `"table"` paints every tile exactly with the table's colour. `GLAZE_HUES`: the Park Güell glaze hues every colour is moved to.
- **The ceramic:** cream ground, white crockery shards, gold lustre, grout, and the ribbon tone of each band.
- **Typeface:** `TEXT_FONT` (Georgia) for the poem, the words on the floor and the text box on WALL 3.

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
| `SIZE_SMALL_MAX`, `SIZE_BIG_MIN`, `SPLIT_WIDE`, `RIBBON_SHARE` | Tile size from raresa, how cells split, share of tiles with the top ribbon (1 = whole lines) |
| `GROUT_*`, `GROUT_SET_FRAMES`, `GLAZE` | Grout width / colour / setting time, glaze sheen |
| "Ceramic look": `SHARD_TILT_DEG`, `GLOSS`, `SPECULAR`, `RIM_*`, `CHIP_DEPTH`, `MARBLE_SHARE`, `RELIEF_TILE_SHARE`, `AO_*`, `CONTACT_SHADOW`… | How real the ceramic looks (`Ceramic.pde`) |
| `TEXTURE_DETAIL` | Resolution of the painted motifs |
| `UI_WIDTH`, `UI_Y`, `UI_SCALE`, `UI_BAR_ALPHA` | The text box on WALL 3 (`UI_SCALE` 2.2 ≈ 9 cm letters in the room) |
| `PREVIEW_INPUT` | Large typed text at the bottom of the preview window |
| `SHOW_POEM` | Floating poem tiles on / off |
| `TEST_MODE` | Start in test mode |
| `TYPED_WORDS_TO_FLOOR` | The visitors' words also float on the floor |
| `CHUNK_SHARDS`, `BURST`, `CHUNK_TILT`, `CHUNK_GROW`, `CHUNK_THICK`, `CHUNK_SHADOW*` | How the tile breaks and travels |
| `SPECIAL_*`, `LAND_GLOW_FRAMES`, `AGAIN_GLOW_FRAMES`, `MARK_GLOW`, `MURAL_SHEEN`, `SWEEP_*`, `CELEBRATE_FRAMES`, `VERSE_*` | The moments (`Moments.pde`) |
| `WHITE_SHARE`, `CRACKLE_SHARE`, `GLASS_SHARE`, `SHARD_MIN` | Less white, crackled glaze, glass shards, smallest shard |
| `THINK_ALPHA` | How opaque the shards turning while the model thinks are |
| `DEBUG_KEYS` | Print every key in the console (accent keys) |
| `TEST_RANDOM` | Test mode with random parameters instead of the real analysis |
| `RICH_SHARD_SIMPLE`, `RICH_SHARD_RICH`, `RICH_ACCENT`, `RICH_GOLD` | Shards from culturalitat (how many, from other tiles) and gold from raresa |
| `LLM_PROVIDER`, `LLM_MODE`, `LOCAL_ENGINE`, `OLLAMA_MODEL_LOCAL` / `_CLOUD`, `MODEL`, `API_KEY` | Language model (the Ollama key lives in `data/ollama_key.txt`) |
| `LLAMA_AUTOSTART`, `LLAMA_SERVER`, `LLAMA_MODEL_FILE`, `LLAMA_PORT`, `LLAMA_CTX`, `LLAMA_START_S` | The local model server (Salamandra on llama-server) |
| `USE_DICTIONARY`, `DICT_URL` | Viquidiccionari definitions sent to the model |
| `USE_WORD_FREQ`, `WORD_FREQ_FILE`, `RARESA_ZIPF` | raresa from word frequency |
| `USE_LEXICON_CACHE`, `LEXICON_CACHE_FILE` | Cache of analysed words |
| `MAX_WORD_LENGTH`, `MSG_*`, `MSG_FRAMES` | Local filter and the messages shown for rejected / corrected words |
| `USE_ACCENT_FIX`, `ACCENT_FIX_GAP`, `ACCENT_FIX_GAP_WRONG`, `ACCENT_WRONG_MAX`, `ACCENT_FIX_MIN` | Correcting missing / wrong accents |
| `MIDI_PORT` | Sound |

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
- **Syphon (macOS) / Spout (Windows)** — the efficient way: set `OUTPUT_SEND = "syphon"` or `"spout"` in `Config.pde`, install that library (*Sketch → Import Library → Manage Libraries*) and remove the `//` before its `import` line at the top of `language_viz.pde` (Processing needs the import to load a library). Each output is sent as "language_viz 1", "language_viz 2"… If the library is missing, the sketch keeps running and the console says what to do.
- **NDI** (e.g. Watchout in the IASLab): Processing has no simple NDI output; bridge it with OBS (Syphon / Spout source + DistroAV NDI output) or TouchDesigner (Syphon Spout In → NDI Out).
- **Windows** — `OUTPUT_WINDOWS = true` opens each output in its own window, full screen on the display set in `OUTPUT_DISPLAYS`. No library needed, but every frame is copied through the CPU (much slower).
- If PIXERA runs on another computer, use NDI or a video output / capture card.

### Room view (`Ctrl+I`, `RoomView.pde`)
To judge the installation before going to the room, `Ctrl+I` turns the preview window into a first-person view from the middle of the room at eye height (`VIEWER_HEIGHT`): the walls (and the floor, if the venue has one) at their real proportions, with exactly the images they will receive. Drag the mouse or use the arrow keys to look around, **right-drag to walk** (up / down = forwards / backwards, sideways = step aside; `Ctrl+I` twice goes back to the centre), the wheel to zoom (55° high to start, close to what the eye takes in). The output is not affected.

Walking shows the real behaviour of the 3D travel (`Ctrl+D`): from the centre (the sweet spot) the pieces seem to fly through the air; elsewhere you see that they are painted on the walls and the illusion bends. In 2D they slide along the walls. The difference is only visible while a tile travels (a few seconds per word).

`Ctrl+J` (off by default: the images as they are) simulates projection: a projector never gives black (`PROJ_BLACK`), the walls light each other — the average brightness of every wall is measured and part of it (`ROOM_BOUNCE`) is added to the others — and `PROJ_GAIN` is how bright the projected white is. Defaults are mild (2 %, 8 %); rooms with white walls bounce much more. The unprojected strip above the image (IASLab: 2.7 m of 3.16 m, `ROOM_EXTRA_H`), the ceiling and, with no floor projection, the floor are lit only by that bounce.

### In the venue
1. Set `ROOM_W`, `ROOM_D`, `WALL_H` to the venue's media matrix and `RENDER_SCALE` to what the machine can hold (check the fps).
2. Press `Ctrl+T`: every surface shows its name, a grid and, on each edge, what should be on the other side ("↑ CEILING", "↓ FLOOR", "WALL 2"…). Walk the room and check. If a wall is rotated, change only its rotation in `setupRoom()` (`Room.pde`).
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
| `Ctrl+E` | Test mode (real analysis shown on WALL 3, nothing saved) |
| `Ctrl+K` | Language test: word list through both filters and the model |
| `Ctrl+O` | Model mode while running: auto → cloud → local (shown at the top of the preview) |
| `Ctrl+I` | Room view: the preview as if standing inside the room (drag / arrows to look around, wheel to zoom) |
| `Ctrl+J` | In the room view: simulate the projectors on / off (black level, light bouncing between walls) |
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
  "word": "pessigolles",
  "emotion": 7,
  "emotion_label": "Alegria",
  "color_hex": "#F08A1C",
  "word_class": 1,
  "abstraction": 5,
  "agency": 4,
  "organic": 7,
  "phenomena_class": 5,
  "time_duration": 2,
  "culturalitat": 4,
  "raresa": 5,
  "zipf": 3.12,
  "definicio": "Sensació que s'experimenta en algunes parts del cos…"
}
```
The model's answer (in the cache) also has `es_catala` (true / false) and `motiu` (why it was rejected).

### `poem_words.json`
The poem: *Diversos són els homes i diverses les parles*, by Salvador Espriu. Its 63 words, in order (articles kept with their noun, as they are read: *els homes*, *l’aire*, *comprèn-la*), each with the parameters of the same analysis as the visitors' words — made by `tools/make_poem_words.py` with the cloud model, giving each word its verse as context (a dictionary definition misled it: *plata* "big plate", *terra* "floor"), and raresa from wordfreq.
```json
{
  "poem": "Diversos són els homes i diverses les parles",
  "author": "Salvador Espriu",
  "text": "Diversos són els homes i diverses les parles,\ni han convingut molts noms a un sol amor.\n…",
  "words": [
    {
      "word": "fràgil",
      "line": 3,
      "emotion": 6,
      "emotion_label": "Tristesa",
      "color_hex": "#4A7BBF",
      "word_class": 3,
      "abstraction": 4,
      "agency": 1,
      "organic": 3,
      "phenomena_class": 2,
      "time_duration": 5,
      "culturalitat": 1,
      "raresa": 4
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
