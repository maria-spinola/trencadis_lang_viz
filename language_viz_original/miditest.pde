//final int CH_PADS  = 0;
//final int CH_LEAD  = 1;


////La nota que toca
//int noteDegree = 1;

//void setup() {
//  size(400, 200);
//  background(20);
//  textAlign(CENTER, CENTER);
//  fill(200);
  
//  setupSoundEngine();
//}

//void draw() {
//}

//void keyPressed() {
//  background(20);

//  // Donald Trump
//  if (key == '1') {
//    text("Donald Trump", width/2, height/2);
//    jsonToMusic("{\"emotion\":1,\"emotion_label\":\"Anger / Rage\",\"color_hex\":\"#B22222\",\"word_class\":1,\"word_class_label\":\"Noun — Circle / Sphere\",\"abstraction\":2,\"agency\":6,\"organic\":2,\"phenomena_class\":3,\"time_duration\":5}");
//  }
//  // Run
//  if (key == '2') {
//    text("Run", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FF7B1A\",\"word_class\":2,\"word_class_label\":\"Verb — Arrow / Streak\",\"abstraction\":2,\"agency\":6,\"organic\":6,\"phenomena_class\":6,\"time_duration\":3}");
//  }
//  // Forward
//  if (key == '3') {
//    text("Forward", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":4,\"phenomena_class\":2,\"time_duration\":4}");
//  }
//  // Vomit
//  if (key == '4') {
//    text("Vomit", width/2, height/2);
//    jsonToMusic("{\"emotion\":5,\"emotion_label\":\"Disgust / Hatred\",\"color_hex\":\"#6B8C2A\",\"word_class\":2,\"word_class_label\":\"Verb — Arrow / Streak\",\"abstraction\":1,\"agency\":5,\"organic\":7,\"phenomena_class\":6,\"time_duration\":1}");
//  }
//  // Stinky
//  if (key == '5') {
//    text("Stinky", width/2, height/2);
//    jsonToMusic("{\"emotion\":5,\"emotion_label\":\"Disgust / Hatred\",\"color_hex\":\"#4A7A1E\",\"word_class\":3,\"word_class_label\":\"Adjective — Irregular blob / Aura\",\"abstraction\":2,\"agency\":1,\"organic\":6,\"phenomena_class\":5,\"time_duration\":2}");
//  }
//  // Galaxy
//  if (key == '6') {
//    text("Galaxy", width/2, height/2);
//    jsonToMusic("{\"emotion\":2,\"emotion_label\":\"Surprise / Amazement\",\"color_hex\":\"#9B4FCC\",\"word_class\":1,\"word_class_label\":\"Noun — Circle / Sphere\",\"abstraction\":5,\"agency\":2,\"organic\":4,\"phenomena_class\":7,\"time_duration\":7}");
//  }
//  // This
//  if (key == '7') {
//    text("This", width/2, height/2);
//    jsonToMusic("{\"emotion\":2,\"emotion_label\":\"Surprise / Amazement\",\"color_hex\":\"#FFE066\",\"word_class\":6,\"word_class_label\":\"Determiner — Dot / Point\",\"abstraction\":6,\"agency\":1,\"organic\":1,\"phenomena_class\":2,\"time_duration\":1}");
//  }
//  // Hers
//  if (key == '8') {
//    text("Hers", width/2, height/2);
//    jsonToMusic("{\"emotion\":4,\"emotion_label\":\"Love / Affection\",\"color_hex\":\"#E87BA0\",\"word_class\":7,\"word_class_label\":\"Pronoun — Hollow ring\",\"abstraction\":5,\"agency\":1,\"organic\":3,\"phenomena_class\":2,\"time_duration\":3}");
//  }
//  // Cemetery
//  if (key == '9') {
//    text("Cemetery", width/2, height/2);
//    jsonToMusic("{\"emotion\":6,\"emotion_label\":\"Sadness\",\"color_hex\":\"#2E3F6E\",\"word_class\":1,\"word_class_label\":\"Noun — Circle / Sphere\",\"abstraction\":3,\"agency\":1,\"organic\":3,\"phenomena_class\":7,\"time_duration\":7}");
//  }
//  // Ectoplasm
//  if (key == '0') {
//    text("Ectoplasm", width/2, height/2);
//    jsonToMusic("{\"emotion\":3,\"emotion_label\":\"Fear / Anxiety\",\"color_hex\":\"#4DB87A\",\"word_class\":1,\"word_class_label\":\"Noun — Circle / Sphere\",\"abstraction\":4,\"agency\":2,\"organic\":7,\"phenomena_class\":4,\"time_duration\":3}");
//  }

//    if (key == 'z') {
//    text("Material finite object or shape", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":1,\"time_duration\":4}");
//  }
//    if (key == 'x') {
//    text("State (elemental, emotional, or situational)", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":2,\"time_duration\":4}");
//  }
//    if (key == 'c') {
//    text("Character (person, entity, archetype)", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":3,\"time_duration\":4}");
//  }
//    if (key == 'v') {
//    text("Material or substance", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":4,\"time_duration\":4}");
//  }
//    if (key == 'b') {
//    text("Object of perception (sensory, experiential)", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":5,\"time_duration\":4}");
//  }
//  if (key == 'n') {
//    text("Action or change of state", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":6,\"time_duration\":4}");
//  }
//  if (key == 'm') {
//    text("Location", width/2, height/2);
//    jsonToMusic("{\"emotion\":7,\"emotion_label\":\"Joy / Happiness\",\"color_hex\":\"#FFB347\",\"word_class\":4,\"word_class_label\":\"Adverb — Curved arc\",\"abstraction\":4,\"agency\":5,\"organic\":5,\"phenomena_class\":7,\"time_duration\":4}");
//  }
//}

//void dispose() {
//  disposeSoundEngine();
//}
