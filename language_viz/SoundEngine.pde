MidiController midi;

void setupSoundEngine() {
  midi = new MidiController(this, MIDI_PORT);
  setupChords();
}

void disposeSoundEngine() {
  try {
    for (int i = 0; i < 7; i++) {
      midi.allNotesOff(CH_LEAD);
    }
    midi.dispose(); // shuts down scheduler + bus before Processing tries to
  }
  catch (Exception e) {
    println("Cleanup error: " + e.getMessage());
  }
  try {
    super.dispose();
  }
  catch (Exception e) {
    // Swallow the themidibus/Processing 4 registration bug
  }
}

void playWord(int emotion, int word_class, int abstraction, int agency, int organic, int phenomena_class, int time_duration) {
  print("emotion: " + emotion, " word_class: " + word_class, " abstraction: " + abstraction, " agency: " + agency, " organic: " + organic, " phenomena_class: " + phenomena_class, " time_duration: " + time_duration);
  playArpeggio(phenomena_class - 1, word_class, floor(map(agency, 1, 7, 10, 127)), emotion, floor(map(abstraction, 1, 7, 0, 500)), floor(map(time_duration, 1, 7, 100, 1000)), floor(map(organic, 1, 7, 0, 2)));
}

void playArpeggio(int channel, int degree, int velocity, int emotion, int stepMs, int noteMs, int octave) {
  int[] chord = buildChord(degree, emotion, octave);
  midi.phrase(channel, chord, velocity, stepMs, noteMs);
  //background(20);
  //text("Note: " + noteDegree + "  Emotion: " + emotion, width/2, height/2);
}
