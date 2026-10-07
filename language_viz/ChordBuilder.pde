// Scale degrees in C major (MIDI, octave 4)
// Index 0 = degree 1 (C), index 6 = degree 7 (B)
int[] cMajorScale = {60, 62, 64, 65, 67, 69, 71};

// Chord quality interval patterns (semitones from root)
HashMap<Integer, int[]> chordPatterns;

void setupChords() {
  chordPatterns = new HashMap<Integer, int[]>();
  chordPatterns.put(1 /* anger */,    new int[]{0, 1, 7, 10});    // root + b2 + 5th + b7
  chordPatterns.put(2 /* surprise */, new int[]{0, 4, 8});        // augmented
  chordPatterns.put(3 /* fear */,     new int[]{0, 3, 6, 9});     // diminished 7th
  chordPatterns.put(4 /* love */,     new int[]{0, 4, 7, 11});    // major 7th
  chordPatterns.put(5 /* disgust */,  new int[]{0, 3, 7, 11});    // minor/major 7th
  chordPatterns.put(6 /* sadness */,  new int[]{0, 3, 7});        // minor
  chordPatterns.put(7 /* joy */,      new int[]{0, 4, 7, 14});    // add9 (14 = maj2nd + octave)
}

// degree: 1–7, emotion: string key, octave: 0 shifts down, 1 = default, 2 shifts up
int[] buildChord(int degree, int emotion, int octave) {
  int root = cMajorScale[(degree - 1) % 7] + (octave - 1) * 12;
  int[] pattern = chordPatterns.get(emotion);
  int[] chord = new int[pattern.length];
  
  for (int i = 0; i < pattern.length; i++) {
    chord[i] = root + pattern[i];
  }
  return chord;
}