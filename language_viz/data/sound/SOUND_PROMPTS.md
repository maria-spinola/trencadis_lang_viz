# Trencadís — sound design prompts

One folder = one event. Put any number of `.wav` files in a folder: the app picks one at
random each time (more files = more variety, no code change). An empty folder is silent.

## How these prompts are built

Best practices from text-to-sound tools (ElevenLabs Sound Effects, Adobe Firefly; the same
words also work in Epidemic Sound's plain-language search):

1. **One sound per prompt.** Generate sequences (crack → crumble) separately and edit them together.
2. **Structure:** *source / action* → *material* → *manner & intensity* → *space & recording* → *shape & length*.
3. **Audio terms help:** foley, close-mic, one-shot, dry, transient, tail, seamless loop, stem.
4. **Ask for isolated sounds:** "isolated, no music, no background". Reverb and mixing happen in the app.
   Exception: chords, moments and the ambient loop, which carry their own space.
5. **Simple first, then add detail.** If the result drifts, raise *prompt influence* (ElevenLabs, default 30 %)
   rather than making the prompt longer. Keep prompts under 450 characters.
6. **Set duration explicitly** (max 30 s in ElevenLabs SFX). Each generation gives 4 takes, so keep the good ones as variants.
7. **Download WAV** (48 kHz). Trim the silence before the attack (latency!) and normalise peaks to about −6 dBFS.

**Shared world (keep it consistent):** glazed Catalan ceramic (trencadís), stone, lime mortar, a large
quiet room with soft stone reverb. Musical material is in **C**, so chords and the bed agree.

---

## ambient/ — background loop (WAV, never MP3)

Several files can live here; the one that plays is `AMBIENT_FILE` in Config.pde. Silence at its end is
cut off and the loop crossfades over `AMBIENT_XFADE` seconds, so it doesn't need to be a perfect loop.

ElevenLabs SFX caps at 30 s: tick **Looping**, set 30 s. Or use a music generator (ElevenLabs Music,
Suno, Udio) for 2–4 min and cut a seamless loop in an editor.

> Seamless ambient drone for an art installation: soft air tone of a large empty stone room, a slow evolving pad centred on C, distant airy shimmer, very gentle movement, no rhythm, no melody, no percussion, calm and dreamy, wide stereo, subtle natural reverb. Seamless loop.

Epidemic search: `calm ambient drone empty room dreamy`

---

## ui/

### ui/key/ — a key typed (6–10 files, 0.05–0.15 s, mono ok)
> Close-mic foley one-shot: a single fingertip tap on a glazed ceramic tile, small bright porcelain click, very short dry transient, soft and delicate, isolated, no background.

Variants: swap "fingertip tap" ↔ "fingernail tick", "glazed ceramic tile" ↔ "small porcelain cup".
Epidemic search: `ceramic tap click small`

### ui/reject/ — word rejected (2–3 files, 0.3–0.8 s)
> Foley one-shot: a soft knock on unglazed terracotta, dull muted clink, low and short, gentle and not harsh, slight room reverb, isolated, no music.

Epidemic search: `muted clay knock soft`

### ui/thinking/ — model thinking, looped (1–2 files, 5–10 s, Looping on)
> Seamless loop: a wet finger slowly rubbing the rim of a ceramic bowl, faint glassy shimmer, very soft sustained tone with gentle wavering, airy and mysterious, quiet, close-mic, isolated.

Epidemic search: `singing bowl rim rub soft shimmer`

---

## chords/ — the word's chord (3–5 files per emotion, 3–8 s)

Same chord types as the MIDI mode (ChordBuilder.pde), all on C so they sit on the ambient bed.
Template. Change the chord and mood, and vary the instrument per take (soft electric piano, felt piano,
warm synth pad, harp, celesta, vibraphone):

> Dreamy single [CHORD] chord, [INSTRUMENT], played as a slow gentle upward arpeggio then held, long lush reverb tail fading to silence, [MOOD], ambient, no drums, no melody, stem, 4 seconds.

| Folder | [CHORD] | [MOOD] |
|---|---|---|
| `1_anger/` | C with flat ninth, fifth and minor seventh (C Db G Bb) | tense, dark, restless |
| `2_surprise/` | C augmented (C E G#) | floating, wondering, suspended |
| `3_fear/` | C diminished seventh (C Eb Gb A) | uneasy, cold, hovering |
| `4_love/` | C major seventh (C E G B) | warm, tender, soft |
| `5_disgust/` | C minor-major seventh (C Eb G B) | bittersweet, uncanny |
| `6_sadness/` | C minor (C Eb G) | melancholic, quiet, slow |
| `7_joy/` | C add nine (C E G D) | bright, open, glowing |

If a tool ignores the notes, keep the chord name and add "in the key of C".

### chords/celebration/ — mural full (1–2 files, 8–12 s)
> Wide swelling C major add nine chord, warm string pad and celesta with soft choir, slowly rising in volume then blooming, shimmering bells on top, long cathedral-like reverb tail, triumphant but gentle, ambient, no drums, 10 seconds.

---

## tile/

### tile/special/ — rare or very Catalan word (2–3 files, 1–3 s)
> Magical sparkle one-shot: a few high celesta and small glass bell notes in C major, cascading softly like golden dust, shimmering tail, delicate, isolated, no drums.

Epidemic search: `magic sparkle chime soft gold`

### tile/break/ — the tile cracks and leaves (3–5 files, 0.3–1 s)
> Close-mic foley one-shot: a glazed ceramic tile snapped in half by hand, clean sharp crack followed by a few tiny crumbling chips, crisp but not violent, dry, isolated, no background.

Epidemic search: `ceramic tile crack snap`

### tile/fly/ — shards flying through the room (2–3 files, 1–3 s, optional)
> Soft airy whoosh passing slowly from left to right, like a silk scarf through the air with faint tinkling of tiny glass fragments, gentle and dreamy, isolated, no music.

Epidemic search: `soft whoosh airy magic`

### tile/shard_land/ — each shard reaching the mural (10–20 files, 0.05–0.3 s, mono ok)
The most-played sound (many per word), so it needs many short, quiet, varied takes.
> Close-mic foley one-shot: a single small glazed ceramic shard dropped onto a pile of broken tiles, short bright clink, light and delicate, dry, isolated, no background.

Variants: "small" ↔ "tiny" ↔ "medium", "onto a pile of broken tiles" ↔ "onto a stone floor" ↔ "against another shard".
Epidemic search: `ceramic shard drop clink small`

### tile/settle/ — grout dries, the tile is set (3–4 files, 0.5–1.5 s)
> Foley one-shot: a mason's trowel pressing a ceramic tile into wet lime mortar, soft low muffled thock with a short wet squelch, satisfying and final, close-mic, dry, isolated.

Epidemic search: `trowel mortar tile press`

### tile/fade/ — an old tile fades away (2–3 files, 1–3 s)
> Soft dissolving sound: fine ceramic dust crumbling away like sand, a gentle breathy exhale with a reversed shimmer, fading to silence, delicate, airy, isolated, no music.

Epidemic search: `dust dissolve reverse soft`

---

## moments/ — the walls move

Name the files `cue_*.wav` (when the tiles start moving) and `hit_*.wav` (when tiles land or impact);
a file with no prefix counts as a hit. Bursts of hits play at most one every `SND_HIT_GAP_MS`.
Note: the wave moment never lands anything, so `moments/wave/hit_*` files are not played.
These may keep some room reverb: they happen in the whole space.

### moments/wave/
- `cue_` (3–6 s): *A rolling wave of clattering ceramic tiles travelling around a large stone room, like rain sweeping across a tiled roof, rising and falling, wide stereo, natural reverb.*
- `hit_` (0.2–0.5 s): *Light clatter of a few ceramic tiles settling back into place, short, soft, room reverb.*

### moments/tilt/
- `cue_` (4–8 s): *A massive stone wall slowly tilting forward, deep low groan and creak of heavy stone, grinding mortar, ominous rumble, cinematic, large room reverb.*
- `hit_` (1–2 s): *Heavy stone slab caught and pushed back into place, deep muffled thud with low rumble, cinematic, large room.*

### moments/heartbeat/
- `hit_` (0.5–1 s, 3–4 takes): *A single deep muffled heartbeat thump, low sub bass pulse, soft and felt more than heard, warm, no music.*

### moments/swap/
- `cue_` (2–4 s): *Two soft whooshes crossing each other through a large room, tinkling ceramic fragments, airy and playful, wide stereo.*
- `hit_` (0.2–0.5 s): *A ceramic tile clicking precisely into its place, satisfying short click, close-mic, dry.*

### moments/collapse/
- `cue_` (4–6 s): *A cascade of ceramic shards falling from a wall and scattering across a stone floor, many tinkling and clattering pieces, slowing down to silence, large room reverb.*
- `return_` (3–5 s, when the border flies back up): *Reversed cascade of ceramic shards rising and gathering, sucked-in reverse shimmer, magical, ending on a soft click.*
- `hit_` (0.1–0.3 s, several): *Single small ceramic tile landing on a stone floor, short clatter and tiny bounce, room reverb.*

---

## Checklist per file
- [ ] WAV, 44.1 or 48 kHz, 16/24-bit (stereo for ambient / chords / moments, mono ok for short sounds)
- [ ] no silence before the attack
- [ ] peaks ≈ −6 dBFS
- [ ] loops (ambient, thinking) click-free at the seam
