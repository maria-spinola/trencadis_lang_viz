// softblur.glsl — a small gaussian blur (σ ≈ 1.5 px) for the soft copies of the mural (Mural.pde: updateThickSoft)
// On the GPU: filter(BLUR) reads the picture back to the CPU, and waiting for it stalled the frame (the walls' moments stuttered)
#ifdef GL_ES
precision mediump float;
#endif
#define PROCESSING_TEXTURE_SHADER
uniform sampler2D texture;
uniform vec2 texOffset;
varying vec4 vertTexCoord;
void main() {
  vec4 sum = vec4(0.0);
  float wsum = 0.0;
  for (int y = -3; y <= 3; y++) {
    for (int x = -3; x <= 3; x++) {
      float w = exp(-float(x * x + y * y) / 4.5);   // 2σ² = 4.5
      sum += texture2D(texture, vertTexCoord.st + vec2(float(x), float(y)) * texOffset) * w;
      wsum += w;
    }
  }
  gl_FragColor = sum / wsum;
}
