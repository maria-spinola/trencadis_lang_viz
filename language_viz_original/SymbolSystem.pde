// ═══════════════════════════════════════════════════════════
// SymbolSystem.pde
// ═══════════════════════════════════════════════════════════

class SymbolFormation {
  float cx, cy;
  color symColor;
  int   wordClass;
  int   sAgency, sOrganic, sPhenomenon;
  float scale;
  int   N;
  boolean isCentral;
  ArrayList<SymParticle> parts = new ArrayList<>();

  SymbolFormation(float cx, float cy, color col, int wordClass,int sAbstract, 
                  int sAgency, int sOrganic, int sPhenomenon,
                  int N, float scaleMultiplier, boolean isCentral) {
    this.cx          = cx;
    this.cy          = cy;
    this.symColor    = col;
    this.wordClass   = wordClass;
    this.sAgency     = sAgency;
    this.sOrganic    = sOrganic;
    this.sPhenomenon = sPhenomenon;
    this.N           = N;
    this.isCentral   = isCentral;
    this.scale = min(width, height) * 0.42  * map(sAbstract, 1, 7, 0.55, 1.0) * scaleMultiplier;
    for (int i = 0; i < N; i++)
      parts.add(new SymParticle(i, N, cx, cy, wordClass, this.scale));
  }

  void update(float life) {
    float currentScale = scale * life;
    for (SymParticle sp : parts)
      sp.update(cx, cy, wordClass, currentScale, sAgency, sOrganic, sPhenomenon);
  }

  void display(float alpha, float life) {
    float currentScale = scale * life;
    for (SymParticle sp : parts)
      sp.display(alpha, symColor, sPhenomenon, currentScale, isCentral);
  }

  void setCenter(float nx, float ny) {
    cx = nx; cy = ny;
  }
}

class SymParticle {
  int   idx, total;
  float offset, colorOffset, depthZ;
  float twinkleSpeed; //Added this
  PVector pos, target;

  SymParticle(int idx, int total, float cx, float cy, int wordClass, float scale) {
    this.idx         = idx;
    this.total       = total;
    this.offset      = random(1000);
    this.colorOffset = random(-8, 8);
    this.depthZ      = random(0.4, 1.0);
    this.twinkleSpeed = random (0.4, 1.0); //added this
    pos    = new PVector(cx + random(-3, 3), cy + random(-3, 3));
    target = new PVector(cx, cy);
  }

  void update(float cx, float cy, int wordClass, float scale, int agency, int organic, int phenomenon) {
    float prog   = (float) idx / total;
    PVector base = symShape(idx, total, prog, scale, wordClass);
    PVector mod  = symPhenomenon(base, idx, prog, scale, phenomenon);
    target.set(mod.x + cx, mod.y + cy);
    float lerpAmt = map(agency,  1, 7, 0.025, 0.15);
    float org     = map(organic, 1, 7, 0.25,  1.0);
    pos.x = lerp(pos.x, target.x + sin(t * 1.5 + idx * 0.07) * 14 * org, lerpAmt);
    pos.y = lerp(pos.y, target.y + cos(t * 1.2 + idx * 0.05) * 14 * org, lerpAmt);
  }

  void display(float alpha, color col, int phenomenon, float scale, boolean isCentral) {
    float d = dist(pos.x, pos.y, 0, 0);
    float h = (hue(col) + map(d, 0, height/2, -8, 12) + colorOffset + 360) % 360;
    float s, b, a;

    if (isCentral) {
      s = constrain(saturation(col) - (1 - depthZ) * 10, 0, 100);
      b = constrain(brightness(col) - (1 - depthZ) * 15, 0, 100);
      a = map(depthZ, 0.4, 1.0, 55, 90) * (alpha / 100.0);
    } else {
      s = min(saturation(col), 85);
      b = constrain(brightness(col) * 0.75 - (1 - depthZ) * 10, 0, 100);
      a = map(depthZ, 0.4, 1.0, 35, 75) * (alpha / 100.0);
    }

    float baseSize;
    switch (phenomenon) {
      case 1: baseSize = isCentral ? 6.0  : 3.0;  break;
      case 2: baseSize = isCentral ? 9.0  : 4.5;  break;
      case 3: baseSize = isCentral ? 7.0  : 3.5;  break;
      case 4: baseSize = isCentral ? 14.0 : 7.0;  break;
      case 5: baseSize = isCentral ? 4.0  : 2.0;  break;
     case 6: baseSize = isCentral ? 10.0 : 5.0;  break;
      case 7: baseSize = isCentral ? 7.0  : 3.5;  break;
     default: baseSize = isCentral ? 7.0  : 3.5;
  
    //  case 1: baseSize = isCentral ? 4.5  : 2.0;  break;
     // case 2: baseSize = isCentral ? 6.5  : 3.0;  break;
     // case 3: baseSize = isCentral ? 5.0  : 2.5;  break;
     // case 4: baseSize = isCentral ? 9.0  : 4.5;  break;
     // case 5: baseSize = isCentral ? 3.0  : 1.5;  break;
     // case 6: baseSize = isCentral ? 7.0  : 3.5;  break;
   //   case 7: baseSize = isCentral ? 5.0  : 2.5;  break;
    //  default: baseSize = isCentral ? 5.0  : 2.5;
    }
    float sz = baseSize * map(depthZ, 0.4, 1.0, 0.6, 1.4);
    float shimmer = 0.75 + 0.25 * sin(t * twinkleSpeed + idx * 0.37);
    sz *= shimmer; // ADDED shimmer

    push();
    translate(pos.x, pos.y, depthZ * 25);
    

  //  strokeWeight(sz);
  //  stroke(h, s, b, a);
  //  noFill();
  //  point(0, 0, 0);
  // Halo to columetric light
   // strokeWeight(sz * 1.8);
   // stroke(h, s * 0.3, b * 0.4, a * 0.08);
   // point(0, 0, 0);
   // pop();
   
   noFill();
   
     // Outer atmosphere — wide, very faint
    strokeWeight(sz * 6.0);
    stroke(h, s * 0.15, b * 0.6, a * 0.04);
    point(0, 0, 0);

    // Mid glow — soft halo
    strokeWeight(sz * 3.2);
    stroke(h, s * 0.25, b * 0.5, a * 0.09);
    point(0, 0, 0);

    // Inner glow — slightly warmer hue for magical ember quality
    strokeWeight(sz * 1.8);
    stroke((h + 15) % 360, s * 0.4, b * 0.75, a * 0.18);
    point(0, 0, 0);

    // Core particle — full color
    strokeWeight(sz);
    stroke(h, s, b, a);
    point(0, 0, 0);

    // Hot spark center — near-white, only for foreground particles (depthZ > 0.8)
    if (depthZ > 0.8) {
      strokeWeight(sz * 0.4);
      stroke(h, s * 0.1, min(b + 20, 100), a * 0.85);
      point(0, 0, 0);
      }

    pop();
  }
}

PVector symShape(int idx, int total, float prog, float scale, int wordClass) {
  switch (wordClass) {
    case 1: {
      float angle = idx * 137.5;
      float r = map(5 * sqrt(idx), 0, 5 * sqrt(total), 0, scale);
      return new PVector(r * cos(radians(angle)), r * sin(radians(angle)));
    }
    case 2: {
      float x = map(prog, 0, 1, -scale * 1.1, scale * 1.1);
      float spread = map(prog, 0, 1, scale * 0.05, scale * 0.35);
      float y = sin(prog * PI) * spread * 0.5 + (noise(idx * 0.3) - 0.5) * spread;
      return new PVector(x, y);
    }
    case 3: {
      float angle  = TWO_PI * prog;
      float jitter = (noise(prog * 4) - 0.5) * 30;
      return new PVector((scale + jitter) * cos(angle), (scale + jitter) * sin(angle));
    }
    case 4: {
      float angle = prog * TWO_PI * 4.5;
      float r = scale * 0.15 + scale * 0.8 * prog;
      return new PVector(r * cos(angle), r * sin(angle));
    }
    case 5: {
      float cluster = floor(noise(idx * 0.07) * 5);
      float angle   = cluster * TWO_PI / 5 + (noise(idx * 0.3) - 0.5);
      float r       = scale * (0.4 + noise(idx * 0.15) * 0.6);
      return new PVector(r * cos(angle), r * sin(angle));
    }
    case 6: {
      int side   = (int) ceil(sqrt(total));
      float step = scale * 1.4 / side;
      return new PVector((idx % side - side/2.0) * step,
                         (idx / side - side/2.0) * step);
    }
    case 7: {
      int numRays      = 16;
      float ray        = floor(noise(idx * 0.11) * numRays);
      float rayAngle   = ray * TWO_PI / numRays + (noise(idx * 0.23) - 0.5) * 0.35;
      float r          = scale * pow(noise(idx * 0.17), 0.6);
      float rayWidth   = r * 0.18;
      float perpOffset = (noise(idx * 0.31) - 0.5) * rayWidth * 2;
      return new PVector(r * cos(rayAngle) + perpOffset * (-sin(rayAngle)),
                         r * sin(rayAngle) + perpOffset * ( cos(rayAngle)));
    }
    case 8: {
      float triR = scale * 0.85;
      PVector v0 = new PVector(0, -triR);
      PVector v1 = new PVector(-triR * 0.866,  triR * 0.5);
      PVector v2 = new PVector( triR * 0.866,  triR * 0.5);
      float r1 = noise(idx * 0.17 + 5);
      float r2 = noise(idx * 0.23 + 50);
      if (r1 + r2 > 1.0) { r1 = 1.0 - r1; r2 = 1.0 - r2; }
      float r3 = 1.0 - r1 - r2;
      float px = r1*v0.x + r2*v1.x + r3*v2.x + (noise(idx*0.41)-0.5)*scale*0.03;
      float py = r1*v0.y + r2*v1.y + r3*v2.y + (noise(idx*0.43)-0.5)*scale*0.03;
      return new PVector(px, py);
    }
    default: return new PVector(0, 0);
  }
}

PVector symPhenomenon(PVector base, int idx, float prog, float scale, int phenomenon) {
  float x = base.x, y = base.y;
  switch (phenomenon) {
    case 1: break;
    case 2: {
      float j = scale * 0.08;
      x += (noise(idx*0.19) - 0.5) * j * 2;
      y += (noise(idx*0.21+50) - 0.5) * j * 2;
      break;
    }
    case 3: {
      float r = sqrt(x*x + y*y);
      float a = atan2(y, x) + sin(r * 0.01) * 0.2;
      x = r*cos(a); y = r*sin(a);
      break;
    }
    case 4: {
      x += (noise(idx*0.07) - 0.5) * scale * 0.18;
      y += (noise(idx*0.07+30) - 0.5) * scale * 0.18;
      break;
    }
    case 5: {
      x += sin(t*4 + idx*0.5) * scale * 0.025;
      y += cos(t*3.7 + idx*0.4) * scale * 0.025;
      break;
    }
    case 6: {
      x += sin(t*1.5 + idx*0.05) * scale * 0.12;
      y += cos(t*1.2 + idx*0.07) * scale * 0.04;
      break;
    }
    case 7: {
      float cl = floor(noise(idx*0.07) * 3);
      float a  = cl * TWO_PI / 3 + (noise(idx*0.3) - 0.5);
      x += cos(a) * scale * 0.1;
      y += sin(a) * scale * 0.1;
      break;
    }
  }
  return new PVector(x, y);
}
