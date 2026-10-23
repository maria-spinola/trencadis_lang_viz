// ═══════════════════════════════════════════════════════════
// SoundEngine.pde
// The sketch says WHAT happens (soundKey, soundWord, soundShardLand…); this decides who plays it:
//   midi     MIDI notes to Reaper (MidiController.pde, ChordBuilder.pde) — exactly as always
//   samples  the WAV files of data/sound (SampleSound.pde)
// SOUND_MODE in Config.pde ("auto": midi if MIDI_PORT exists); Ctrl+S switches while it runs.
// Events with no MIDI sound (break, settle, moments…) are only heard in samples mode.
// ═══════════════════════════════════════════════════════════

MidiController midi;
SampleSound samples;
String soundMode = "";   // "midi" or "samples", once started

void setupSoundEngine() {
  String m = SOUND_MODE.toLowerCase();
  if (m.equals("auto")) m = midiPortExists() ? "midi" : "samples";
  setSoundMode(m.equals("samples") ? "samples" : "midi");
}

boolean midiPortExists() {
  try {
    for (String s : MidiBus.availableOutputs()) if (s.equals(MIDI_PORT)) return true;
  } catch (Exception e) { }
  println("Sound: MIDI port \"" + MIDI_PORT + "\" not found");
  return false;
}

void setSoundMode(String m) {
  if (m.equals("midi")) {
    if (samples != null) samples.stop();
    if (midi == null) midi = new MidiController(this, MIDI_PORT);
  } else {
    if (midi != null) midiAllNotesOff();
    if (samples == null) samples = new SampleSound(this);
    samples.start();
  }
  soundMode = m;
  println("Sound: " + (m.equals("midi") ? "MIDI → Reaper (" + MIDI_PORT + ")" : "samples (data/" + SOUND_DIR + ")"));
}

void toggleSoundMode() {
  if (soundReady) setSoundMode(soundMode.equals("midi") ? "samples" : "midi");
}

boolean midiOn()    { return soundReady && soundMode.equals("midi") && midi != null; }
boolean samplesOn() { return soundReady && soundMode.equals("samples") && samples != null; }

void updateSound() {
  if (samples != null) samples.update();
  updateMomentSounds();
}

void midiAllNotesOff() {
  for (int ch = 0; ch <= 7; ch++) midi.allNotesOff(ch);   // the 7 word channels and the percussion
}

void disposeSoundEngine() {
  try {
    if (midi != null) {
      midiAllNotesOff();
      midi.dispose(); // shuts down scheduler + bus before Processing tries to
    }
  }
  catch (Exception e) {
    println("Cleanup error: " + e.getMessage());
  }
  if (samples != null) samples.dispose();
  try {
    super.dispose();
  }
  catch (Exception e) {
    // Swallow the themidibus/Processing 4 registration bug
  }
}

// ── The events ──────────────────────────────────────────────

// a key typed in the text box (a visitor's, or the room's own: AutoWords.pde)
void soundKey() {
  if (midiOn()) playNote(7, 48, floor(random(45, 60)), 250);
  else if (samplesOn()) samples.key();
}

// a word accepted: its tile appears (JSONLoader.pde)
void soundWord(int emotion, int word_class, int abstraction, int agency, int organic, int phenomena_class, int time_duration) {
  if (midiOn()) playWord(emotion, word_class, abstraction, agency, organic, phenomena_class, time_duration);
  else if (samplesOn()) samples.word(emotion, agency, phenomena_class);
}

// the mural is full (Moments.pde)
void soundCelebration() {
  if (midiOn()) playWord(7, 1, 4, 7, 4, 1, 7);
  else if (samplesOn()) samples.celebrate();
}

// a piece of the tile reaches its place (Mosaic.pde)
void soundShardLand() {
  if (midiOn()) playNote(7, 52, floor(random(80, 100)), 500);
  else if (samplesOn()) samples.shardLand();
}

// samples only
void soundReject()    { if (samplesOn()) samples.reject(); }      // not a Catalan word (CatalanLLM.pde)
void soundSpecial()   { if (samplesOn()) samples.special(); }     // a rare or very Catalan word (Mosaic.pde)
void soundTileBreak() { if (samplesOn()) samples.tileBreak(); }   // the tile breaks and leaves the main wall
void soundTileFly()   { if (samplesOn()) samples.tileFly(); }     // its pieces set off through the room
void soundSettle()    { if (samplesOn()) samples.settle(); }      // the grout has set: it is in the mural
void soundFade()      { if (samplesOn()) samples.fade(); }        // an old tile fades away to make room
void soundMomentHit(String name) { if (samplesOn()) samples.momentHit(name); }   // WallMoments.pde: something lands

// The moments of the walls: the cue when the tiles start moving (after the light has dimmed),
// the collapse's way back when the border flies up again. Nothing more once a visitor interrupts.
int sndFxStart = -1;
boolean sndFxGo, sndFxBack;
void updateMomentSounds() {
  if (!fxActive() || !samplesOn()) return;
  if (fxStart != sndFxStart) { sndFxStart = fxStart; sndFxGo = sndFxBack = false; }
  if (fxAbortAt >= 0) return;
  int t = frameCount - fxStart - WALL_MOMENTS_CUE;
  String name = FX_NAMES[fxType];
  if (!sndFxGo && t >= 0) { sndFxGo = true; samples.momentCue(name); }
  if (fxType == FX_COLLAPSE && !sndFxBack && t >= COLLAPSE_BACK) { sndFxBack = true; samples.momentReturn(name); }
}

// ── MIDI (Reaper) ───────────────────────────────────────────

void playWord(int emotion, int word_class, int abstraction, int agency, int organic, int phenomena_class, int time_duration) {
  print("emotion: " + emotion, " word_class: " + word_class, " abstraction: " + abstraction, " agency: " + agency, " organic: " + organic, " phenomena_class: " + phenomena_class, " time_duration: " + time_duration);
  playArpeggio(phenomena_class - 1, word_class, floor(map(agency, 1, 7, 30, 100)), emotion, floor(map(abstraction, 1, 7, 0, 500)), floor(map(time_duration, 1, 7, 100, 1000)), floor(map(organic, 1, 7, 0, 2)));
}

void playArpeggio(int channel, int degree, int velocity, int emotion, int stepMs, int noteMs, int octave) {
  int[] chord = buildChord(degree, emotion, octave);
  midi.phrase(channel, chord, velocity, stepMs, noteMs);
  //background(20);
  //text("Note: " + noteDegree + "  Emotion: " + emotion, width/2, height/2);
}

void playNote(int channel, int pitch, int velocity, int durationMs) {
  midi.note(channel, pitch, velocity, durationMs);
}
