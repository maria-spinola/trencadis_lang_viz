// ═══════════════════════════════════════════════════════════
// SampleSound.pde
// The samples mode of the sound (SOUND_MODE in Config.pde, Ctrl+S): instead of MIDI notes to
// Reaper, the sketch plays the WAV files of data/sound itself, with Minim.
//
//   data/sound/<folder>/   one folder per event: any number of files, one picked at random
//                          (never the same twice in a row); an empty folder is silent
//   ambient/AMBIENT_FILE   the bed, looping all the time, its end overlapping its beginning
//   moments/<name>/        cue_*  when the moment starts moving, hit_* (or no prefix) when
//                          something lands, return_* when the collapse flies back
//
// The files load in the background (the room doesn't wait): each one is trimmed of the silence
// before its attack and after its tail, and levelled to the same peak (SND_TARGET_DB), so files
// from different tools sit together; SND_* in Config.pde sets each event's volume on top.
// One mixer (SndMixer) plays them all: a few voices, the oldest one-shot gives way.
// ═══════════════════════════════════════════════════════════

import ddf.minim.*;
import ddf.minim.ugens.*;

final String[] CHORD_FOLDERS = { "1_anger", "2_surprise", "3_fear", "4_love", "5_disgust", "6_sadness", "7_joy" };   // by emotion (ChordBuilder.pde)

// A sound in memory, ready to play
class Clip {
  final String name, role;   // role: "cue", "hit" or "return" (moments), "" elsewhere
  final float sr;
  final float[] L, R;
  Clip(String name, String role, float sr, float[] L, float[] R) { this.name = name; this.role = role; this.sr = sr; this.L = L; this.R = R; }
  int length() { return L.length; }
}

class SampleSound {
  Minim minim;
  AudioOutput out;
  SndMixer mixer;
  java.util.concurrent.ConcurrentHashMap<String, ArrayList<Clip>> folders = new java.util.concurrent.ConcurrentHashMap<String, ArrayList<Clip>>();
  HashMap<String, Clip> lastPicked = new HashMap<String, Clip>();
  HashMap<String, Integer> lastHit = new HashMap<String, Integer>();
  volatile Clip ambient;
  volatile boolean loaded = false;
  boolean active = false;
  long ambientId = 0, thinkingId = 0;

  SampleSound(PApplet app) {
    minim = new Minim(app);
    out = minim.getLineOut(Minim.STEREO, 1024, 48000);
    if (out == null) out = minim.getLineOut(Minim.STEREO);
    mixer = new SndMixer(SND_VOICES);
    mixer.patch(out);
    final File root = new File(dataPath(SOUND_DIR));
    new Thread(() -> load(root), "sound-loader").start();
  }

  // ── Loading ──

  void load(File root) {
    int t0 = millis(), n = 0;
    File amb = new File(new File(root, "ambient"), AMBIENT_FILE);
    if (amb.exists()) ambient = loadClip(amb, "");
    else println("Sound: no ambient file " + amb.getPath());
    ArrayList<File> dirs = new ArrayList<File>();
    listDirs(root, dirs);
    for (File d : dirs) {
      String key = root.toURI().relativize(d.toURI()).getPath();
      if (key.endsWith("/")) key = key.substring(0, key.length() - 1);
      if (key.length() == 0 || key.equals("ambient")) continue;   // the bed is only AMBIENT_FILE
      File[] files = d.listFiles();
      if (files == null) continue;
      java.util.Arrays.sort(files);
      ArrayList<Clip> clips = new ArrayList<Clip>();
      for (File f : files) {
        if (!f.isFile() || !isAudio(f.getName())) continue;
        String nm = f.getName().toLowerCase();
        String role = !key.startsWith("moments/") ? ""
                    : nm.startsWith("cue_") ? "cue" : nm.startsWith("return_") ? "return" : "hit";
        Clip c = loadClip(f, role);
        if (c != null) clips.add(c);
      }
      if (clips.size() > 0) { folders.put(key, clips); n += clips.size(); }
    }
    loaded = true;
    println("Sound: " + n + " samples in " + folders.size() + " folders" + (ambient != null ? " + ambient" : "") + " (" + (millis() - t0) + " ms)");
  }

  void listDirs(File d, ArrayList<File> dirs) {
    dirs.add(d);
    File[] sub = d.listFiles();
    if (sub == null) return;
    java.util.Arrays.sort(sub);
    for (File s : sub) if (s.isDirectory()) listDirs(s, dirs);
  }

  boolean isAudio(String nm) {
    nm = nm.toLowerCase();
    return nm.endsWith(".wav") || nm.endsWith(".mp3") || nm.endsWith(".aif") || nm.endsWith(".aiff");
  }

  // Decoded, trimmed (silence before the attack and after the tail) and levelled
  Clip loadClip(File f, String role) {
    try {
      MultiChannelBuffer b = new MultiChannelBuffer(1, 2);
      float sr = minim.loadFileIntoBuffer(f.getAbsolutePath(), b);
      if (sr <= 0 || b.getBufferSize() < 2) { println("Sound: can't read " + f.getName()); return null; }
      float[] L = b.getChannel(0), R = b.getChannelCount() > 1 ? b.getChannel(1) : L;
      int n = L.length;
      float peak = 0;
      for (int i = 0; i < n; i++) peak = max(peak, max(abs(L[i]), abs(R[i])));
      if (peak < 1e-5) { println("Sound: silent file " + f.getName()); return null; }
      float lead = peak * dbToAmp(SND_TRIM_DB), tail = peak * dbToAmp(-60);
      int s = 0, e = n - 1;
      while (s < n && abs(L[s]) < lead && abs(R[s]) < lead) s++;
      while (e > s && abs(L[e]) < tail && abs(R[e]) < tail) e--;
      s = max(0, s - round(0.003 * sr));   // a hair of what comes before the attack
      e = min(n, e + 1 + round(0.02 * sr));
      int m = e - s;
      float g = min(dbToAmp(SND_TARGET_DB) / peak, dbToAmp(SND_MAX_BOOST_DB));
      float[] l = new float[m], r = new float[m];
      int fin = max(1, round(0.002 * sr)), fout = max(1, min(m / 4, round(0.03 * sr)));   // no clicks at the cuts
      for (int i = 0; i < m; i++) {
        float k = g * min(1, min(i / (float) fin, (m - 1 - i) / (float) fout));
        l[i] = L[s + i] * k;
        r[i] = R[s + i] * k;
      }
      return new Clip(f.getName(), role, sr, l, r);
    } catch (Exception ex) {
      println("Sound: can't load " + f.getName() + " — " + ex.getMessage());
      return null;
    }
  }

  float dbToAmp(float db) { return pow(10, db / 20.0); }

  // ── Picking and playing ──

  Clip pick(String folder, String role) {
    ArrayList<Clip> all = folders.get(folder);
    if (all == null) return null;
    ArrayList<Clip> ok = new ArrayList<Clip>();
    for (Clip c : all) if (role == null || c.role.equals(role)) ok.add(c);
    if (ok.size() == 0) return null;
    String key = folder + "|" + role;
    Clip last = lastPicked.get(key), c;
    do c = ok.get((int) random(ok.size())); while (ok.size() > 1 && c == last);
    lastPicked.put(key, c);
    return c;
  }

  long play(String folder, float amp, float rateJitter) { return play(folder, null, amp, rateJitter); }

  long play(String folder, String role, float amp, float rateJitter) {
    if (!active) return 0;
    Clip c = pick(folder, role);
    if (c == null) return 0;
    int prio = folder.startsWith("chords/") || folder.startsWith("moments/") ? 2 : folder.equals("tile/shard_land") || folder.equals("ui/key") ? 0 : 1;
    return mixer.play(c, amp, 1 + random(-rateJitter, rateJitter), false, 0, 0, prio);
  }

  // a burst of impacts plays as one every SND_HIT_GAP_MS
  boolean throttle(String key) {
    Integer t = lastHit.get(key);
    int gap = key.equals("shard") ? SND_SHARD_GAP_MS : SND_HIT_GAP_MS;
    if (t != null && millis() - t < gap) return false;
    lastHit.put(key, millis());
    return true;
  }

  // ── Switching on and off (SoundEngine.pde: setSoundMode) ──

  void start() { active = true; }

  void stop() {
    active = false;
    mixer.fadeAll(1.5);
    ambientId = thinkingId = 0;
  }

  // Every frame: the bed, and the loop while the model thinks
  void update() {
    if (!active) return;
    if (ambientId == 0 && ambient != null)
      ambientId = mixer.play(ambient, SND_AMBIENT, 1, true, AMBIENT_XFADE, AMBIENT_FADE_IN, 3);
    boolean think = isLoading;
    if (think && thinkingId == 0) {
      Clip c = pick("ui/thinking", null);
      if (c != null) thinkingId = mixer.play(c, SND_THINKING, 1, true, 0.5, 0.8, 3);
      else thinkingId = -1;   // nothing to play: don't look again until it stops
    } else if (!think && thinkingId != 0) {
      if (thinkingId > 0) mixer.fadeOut(thinkingId, 1.0);
      thinkingId = 0;
    }
  }

  void dispose() {
    try { out.close(); minim.stop(); } catch (Exception e) { }
  }

  // ── The events ──

  void key()        { play("ui/key", SND_KEY * random(0.7, 1), 0.05); }
  void reject()     { play("ui/reject", SND_REJECT, 0); }
  void special()    { play("tile/special", SND_SPECIAL, 0); }
  void tileBreak()  { play("tile/break", SND_BREAK * random(0.8, 1), 0.04); }
  void tileFly()    { play("tile/fly", SND_FLY * random(0.7, 1), 0.05); }
  void shardLand()  { if (throttle("shard")) play("tile/shard_land", SND_SHARD * random(0.6, 1), 0.08); }   // a tile has ~16 pieces: a few clinks, not a wall of them
  void settle()     { play("tile/settle", SND_SETTLE, 0.03); }
  void fade()       { play("tile/fade", SND_FADE, 0); }
  void celebrate()  { play("chords/celebration", SND_CELEBRATION, 0); }

  // The chord of the word's emotion (chords/<n_emotion>/<phenomena_class>/ first, if that folder exists);
  // stays in C: no pitch change, only louder with more agency
  void word(int emotion, int agency, int phenomena) {
    String f = "chords/" + CHORD_FOLDERS[constrain(emotion, 1, 7) - 1];
    float amp = SND_CHORD * map(constrain(agency, 1, 7), 1, 7, 0.6, 1);
    if (play(f + "/" + phenomena, amp, 0) == 0) play(f, amp, 0);
  }

  void momentCue(String name)    { play("moments/" + name, "cue", SND_MOMENTS, 0); }
  void momentReturn(String name) { play("moments/" + name, "return", SND_MOMENTS, 0); }
  void momentHit(String name) {
    if (throttle("hit|" + name)) play("moments/" + name, "hit", SND_MOMENTS * random(0.7, 1), 0.05);
  }
}

// ── The mixer: runs in the audio thread ──
// The sketch asks for sounds through a queue (play, fade); everything else happens here, sample by
// sample: each voice reads its clip at its own speed (the file's sample rate × a little pitch
// jitter), loops overlap their end with their beginning, and the sum is softly limited.

class SndVoice {
  Clip c;
  long id, started;
  int prio;   // who gives way when every voice is busy: 0 shards and keys first … 3 the loops, never
  double pos;
  float amp, step, gain, target, gainStep;
  boolean on, loop;
  int xfade;
}

class SndMixer extends UGen {
  SndVoice[] voices;
  java.util.concurrent.ConcurrentLinkedQueue<Runnable> todo = new java.util.concurrent.ConcurrentLinkedQueue<Runnable>();
  java.util.concurrent.atomic.AtomicLong ids = new java.util.concurrent.atomic.AtomicLong();
  long clock = 0;

  SndMixer(int n) {
    voices = new SndVoice[max(2, n)];
    for (int i = 0; i < voices.length; i++) voices[i] = new SndVoice();
  }

  // xfade: seconds the loop's end overlaps its beginning; fadeIn: seconds to come in
  long play(final Clip c, final float amp, final float rate, final boolean loop, final float xfade, final float fadeIn, final int prio) {
    final long id = ids.incrementAndGet();
    todo.add(() -> {
      SndVoice v = freeVoice(prio);
      if (v == null) return;   // everything busy with more important sounds
      float sr = sampleRate();
      v.c = c; v.id = id; v.started = clock; v.on = true; v.loop = loop; v.prio = prio;
      v.pos = 0; v.amp = amp; v.step = rate * c.sr / sr;
      v.xfade = loop ? min(round(xfade * c.sr), c.length() / 2) : 0;
      v.target = 1;
      if (fadeIn > 0) { v.gain = 0; v.gainStep = 1 / (fadeIn * sr); }
      else            { v.gain = 1; v.gainStep = 0; }
    });
    return id;
  }

  void fadeOut(final long id, final float sec) {
    todo.add(() -> { for (SndVoice v : voices) if (v.on && v.id == id) fadeVoice(v, sec); });
  }

  void fadeAll(final float sec) {
    todo.add(() -> { for (SndVoice v : voices) if (v.on) fadeVoice(v, sec); });
  }

  void fadeVoice(SndVoice v, float sec) {
    v.target = 0;
    v.gainStep = v.gain / max(1, sec * sampleRate());
  }

  // a free voice, or the least important one-shot (the oldest of those) — never one more important
  // than the new sound, never a loop
  SndVoice freeVoice(int prio) {
    SndVoice old = null;
    for (SndVoice v : voices) {
      if (!v.on) return v;
      if (v.loop || v.prio > prio) continue;
      if (old == null || v.prio < old.prio || (v.prio == old.prio && v.started < old.started)) old = v;
    }
    return old;
  }

  protected void uGenerate(float[] ch) {
    Runnable r;
    while ((r = todo.poll()) != null) r.run();
    clock++;
    float l = 0, rr = 0;
    for (SndVoice v : voices) {
      if (!v.on) continue;
      Clip c = v.c;
      int n = c.length();
      int i = (int) v.pos;
      if (i >= n - 1) { v.on = false; continue; }
      float fr = (float) (v.pos - i);
      float sl = c.L[i] + (c.L[i + 1] - c.L[i]) * fr;
      float sr = c.R[i] + (c.R[i + 1] - c.R[i]) * fr;
      if (v.loop && v.xfade > 0 && i >= n - v.xfade) {   // the end fades out as the beginning fades in
        int k = i - (n - v.xfade);
        float t = k / (float) v.xfade, a = sqrt(1 - t), b = sqrt(t);
        sl = sl * a + c.L[k] * b;
        sr = sr * a + c.R[k] * b;
      }
      if (v.gain != v.target) {
        if (v.target > v.gain) v.gain = min(v.target, v.gain + v.gainStep);
        else                   v.gain = max(v.target, v.gain - v.gainStep);
        if (v.gain <= 0 && v.target <= 0) { v.on = false; continue; }
      }
      float g = v.amp * v.gain;
      l += sl * g;
      rr += sr * g;
      v.pos += v.step;
      if (v.loop && v.pos >= n - 1) v.pos = v.pos - (n - 1) + v.xfade;   // on from where the overlap left it
    }
    l *= SND_MASTER; rr *= SND_MASTER;
    if (ch.length == 1) ch[0] = soft((l + rr) / 2);
    else { ch[0] = soft(l); ch[1] = soft(rr); for (int k = 2; k < ch.length; k++) ch[k] = 0; }
  }

  // untouched below 0.8, rounded off above: many sounds at once never clip hard
  float soft(float x) {
    float a = abs(x);
    if (a <= 0.8) return x;
    return Math.signum(x) * (0.8 + 0.2 * (float) Math.tanh((a - 0.8) / 0.2));
  }
}
