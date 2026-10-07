import java.util.concurrent.*;
import themidibus.*;

class MidiController {

  private MidiBus bus;
  private ScheduledExecutorService scheduler;

  //MidiController(Object parent, String portName) { 
  //  bus = new MidiBus(parent, -1, portName);
  //  scheduler = Executors.newScheduledThreadPool(8);
  //  println("MidiController ready → " + portName);
  //}
  
  MidiController(PApplet parent, String portName) {
    try {
      // Inicializar MidiBus sin registrar el parent — evita el bug con P3D
      bus = new MidiBus(parent, -1, portName);
    } catch (Exception e) {
      println("MidiBus init error (ignorado): " + e.getMessage());
      // Intentar sin parent
      bus = new MidiBus(this, -1, portName);
    }
    scheduler = Executors.newScheduledThreadPool(8);
    println("MidiController ready → " + portName);
  }
  
  // Fire a note and automatically schedule its noteOff — like a promise
  void note(int channel, int pitch, int velocity, int durationMs) {
    bus.sendNoteOn(channel, pitch, velocity);

    scheduler.schedule(
      () -> bus.sendNoteOff(channel, pitch, 0),
      durationMs,
      TimeUnit.MILLISECONDS
      );
  }

  // Play a phrase: array of pitches, step time between notes, note duration
  void phrase(int channel, int[] pitches, int velocity, int stepMs, int noteMs) {
    for (int i = 0; i < pitches.length; i++) {
      final int pitch = pitches[i];
      final int delayMs = i * stepMs;

      scheduler.schedule(
        () -> note(channel, pitch, velocity, noteMs),
        delayMs,
        TimeUnit.MILLISECONDS
        );
    }
  }

  // Phrase with per-note velocities
  void phrase(int channel, int[] pitches, int[] velocities, int stepMs, int noteMs) {
    for (int i = 0; i < pitches.length; i++) {
      final int pitch = pitches[i];
      final int vel   = velocities[i];
      final int delayMs = i * stepMs;

      scheduler.schedule(
        () -> note(channel, pitch, vel, noteMs),
        delayMs,
        TimeUnit.MILLISECONDS
        );
    }
  }

  void cc(int channel, int ccNumber, int value) {
    bus.sendControllerChange(channel, ccNumber, value);
  }

  // Smooth CC sweep _from current _to target over durationMs
  void ccSweep(int channel, int ccNumber, int _from, int _to, int durationMs) {
    int steps = 20;
    int stepDelay = durationMs / steps;

    for (int i = 0; i <= steps; i++) {
      final int val = (int) lerp(_from, _to, (float) i / steps);
      final int delay = i * stepDelay;

      scheduler.schedule(
        () -> bus.sendControllerChange(channel, ccNumber, val),
        delay,
        TimeUnit.MILLISECONDS
        );
    }
  }

  void allNotesOff(int channel) {
    bus.sendControllerChange(channel, 123, 0); // CC 123 = All Notes Off
  }

  // Call this in your sketch's exit() or when done
  void dispose() {
    scheduler.shutdownNow();
    bus.dispose();
  }
}
